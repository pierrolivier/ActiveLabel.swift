//
//  RegexParser.swift
//  ActiveLabel
//
//  Created by Pol Quintana on 06/01/16.
//  Copyright © 2016 Optonaut. All rights reserved.
//

import Foundation

struct RegexParser {

    static let hashtagPattern = "(?:^|\\s|$)#[\\p{L}0-9_]*"
    static let mentionPattern = "(?:^|\\s|$|[.])@[\\p{L}0-9_]+(?:\\.[\\p{L}0-9_]+)*"
    static let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    static let urlPattern = "(^|[\\s.:;?\\-\\(])((https?://|www\\.|[a-zA-Z][a-zA-Z0-9+.-]*://)?[\\w-]+\\.[a-zA-Z]{2,}([\\w./?&%=+-]*[\\w/])?|([a-zA-Z][a-zA-Z0-9+.-]*://[\\w./?&%=+-]*))(?=$|[\\s.,:;?\\-\\)])"
    
    private static var cachedRegularExpressions: [String: NSRegularExpression] = [:]

    static func getElements(from text: String, with pattern: String, range: NSRange) -> [NSTextCheckingResult] {
        guard let regex = regularExpression(for: pattern) else { return [] }
        return regex.matches(in: text, options: [], range: range)
    }

    private static func regularExpression(for pattern: String) -> NSRegularExpression? {
        if let regex = cachedRegularExpressions[pattern] {
            return regex
        }
        
        let newRegex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        if let newRegex = newRegex {
            cachedRegularExpressions[pattern] = newRegex
        }
        
        return newRegex
    }
}
