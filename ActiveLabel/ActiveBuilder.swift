//
//  ActiveBuilder.swift
//  ActiveLabel
//
//  Created by Pol Quintana on 04/09/16.
//  Copyright © 2016 Optonaut. All rights reserved.
//

import Foundation

typealias ActiveFilterPredicate = ((String) -> Bool)

struct ActiveBuilder {

    static func createElements(type: ActiveType, from text: String, range: NSRange, filterPredicate: ActiveFilterPredicate?) -> [ElementTuple] {
        switch type {
        case .mention, .hashtag:
            return createElementsIgnoringFirstCharacter(from: text, for: type, range: range, filterPredicate: filterPredicate)
        case .url:
            return createElements(from: text, for: type, range: range, filterPredicate: filterPredicate)
        case .custom:
            return createElements(from: text, for: type, range: range, minLength: 1, filterPredicate: filterPredicate)
        case .email:
            return createElements(from: text, for: type, range: range, filterPredicate: filterPredicate)
        }
    }
    
    static func createURLElements(from text: String, range: NSRange, maximumLength: Int?) -> ([ElementTuple], String) {
        let type = ActiveType.url
        var text = text
        let matches = RegexParser.getElements(from: text, with: type.pattern, range: range)
        let nsstring = text as NSString
        var elements: [ElementTuple] = []

        for match in matches where match.range.length > 2 {
            let word = nsstring.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let trimmedWord: String
            if let maxLength = maximumLength, word.count > maxLength {
                trimmedWord = word.trim(to: maxLength)
                text = text.replacingOccurrences(of: word, with: trimmedWord)
            } else {
                trimmedWord = word
            }
            
            let newRange = (text as NSString).range(of: trimmedWord)
            let validURL = word.contains("://") ? word : "https://\(word)"
            let element = ActiveElement.url(original: validURL, trimmed: trimmedWord)
            elements.append((newRange, element, type))
        }

        return (elements, text)
    }

    private static func createElements(from text: String, for type: ActiveType, range: NSRange, minLength: Int = 2, filterPredicate: ActiveFilterPredicate?) -> [ElementTuple] {
        let matches = RegexParser.getElements(from: text, with: type.pattern, range: range)
        let nsstring = text as NSString
        
        return matches
            .filter { $0.range.length > minLength }
            .compactMap { match -> ElementTuple? in
                let word = nsstring.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
                guard filterPredicate?(word) ?? true else { return nil }
                let element = ActiveElement.create(with: type, text: word)
                return (match.range, element, type)
            }
    }
    
    private static func createElementsIgnoringFirstCharacter(from text: String, for type: ActiveType, range: NSRange, filterPredicate: ActiveFilterPredicate?) -> [ElementTuple] {
        let matches = RegexParser.getElements(from: text, with: type.pattern, range: range)
        let nsstring = text as NSString

        return matches
            .filter { $0.range.length > 2 }
            .compactMap { match -> ElementTuple? in
                let adjustedRange = NSRange(location: match.range.location + 1, length: match.range.length - 1)
                var word = nsstring.substring(with: adjustedRange)
                
                if word.hasPrefix("@") || word.hasPrefix("#") {
                    word.remove(at: word.startIndex)
                }

                guard filterPredicate?(word) ?? true else { return nil }
                let element = ActiveElement.create(with: type, text: word)
                return (match.range, element, type)
            }
    }
}
