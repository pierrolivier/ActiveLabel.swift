//
//  ActiveLabel.swift
//  ActiveLabel
//
//  Created by Johannes Schickling on 9/4/15.
//  Copyright © 2015 Optonaut. All rights reserved.
//

import Foundation
import UIKit

public protocol ActiveLabelDelegate: AnyObject {
    func didSelect(_ text: String, type: ActiveType)
}

public typealias ConfigureLinkAttribute = (ActiveType, [NSAttributedString.Key : Any], Bool) -> ([NSAttributedString.Key : Any])
typealias ElementTuple = (range: NSRange, element: ActiveElement, type: ActiveType)

@IBDesignable open class ActiveLabel: UILabel {
    
    // MARK: - public properties
    
    open weak var delegate: ActiveLabelDelegate?
    
    open var enabledTypes: [ActiveType] = [.mention, .hashtag, .url]
    
    open var urlMaximumLength: Int?
    
    open var configureLinkAttribute: ConfigureLinkAttribute?
    
    @IBInspectable open var mentionColor: UIColor = .blue {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable open var mentionSelectedColor: UIColor? {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable open var hashtagColor: UIColor = .blue {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable open var hashtagSelectedColor: UIColor? {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable open var URLColor: UIColor = .blue {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable open var URLSelectedColor: UIColor? {
        didSet { updateTextStorage(parseText: false) }
    }
    open var customColor: [ActiveType : UIColor] = [:] {
        didSet { updateTextStorage(parseText: false) }
    }
    open var customSelectedColor: [ActiveType : UIColor] = [:] {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable public var lineSpacing: CGFloat = 0 {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable public var minimumLineHeight: CGFloat = 0 {
        didSet { updateTextStorage(parseText: false) }
    }
    @IBInspectable public var highlightFontName: String? = nil {
        didSet { updateTextStorage(parseText: false) }
    }
    public var highlightFontSize: CGFloat? = nil {
        didSet { updateTextStorage(parseText: false) }
    }
    
    // MARK: - Computed Properties
    
    private var hightlightFont: UIFont? {
        guard let highlightFontName = highlightFontName, let highlightFontSize = highlightFontSize else { return nil }
        return UIFont(name: highlightFontName, size: highlightFontSize)
    }
    
    // MARK: - public methods
    
    open func handleMentionTap(_ handler: @escaping (String) -> ()) {
        mentionTapHandler = handler
    }
    
    open func handleHashtagTap(_ handler: @escaping (String) -> ()) {
        hashtagTapHandler = handler
    }
    
    open func handleURLTap(_ handler: @escaping (URL) -> ()) {
        urlTapHandler = handler
    }
    
    open func handleCustomTap(for type: ActiveType, handler: @escaping (String) -> ()) {
        customTapHandlers[type] = handler
    }
    
    open func handleEmailTap(_ handler: @escaping (String) -> ()) {
        emailTapHandler = handler
    }
    
    open func removeHandle(for type: ActiveType) {
        switch type {
        case .hashtag:
            hashtagTapHandler = nil
        case .mention:
            mentionTapHandler = nil
        case .url:
            urlTapHandler = nil
        case .custom:
            customTapHandlers[type] = nil
        case .email:
            emailTapHandler = nil
        }
    }
    
    open func filterMention(_ predicate: @escaping (String) -> Bool) {
        mentionFilterPredicate = predicate
        updateTextStorage()
    }
    
    open func filterHashtag(_ predicate: @escaping (String) -> Bool) {
        hashtagFilterPredicate = predicate
        updateTextStorage()
    }
    
    // MARK: - override UILabel properties
    
    override open var text: String? {
        didSet { updateTextStorage() }
    }
    
    override open var attributedText: NSAttributedString? {
        didSet { updateTextStorage() }
    }
    
    override open var font: UIFont! {
        didSet { updateTextStorage(parseText: false) }
    }
    
    override open var textColor: UIColor! {
        didSet { updateTextStorage(parseText: false) }
    }
    
    override open var textAlignment: NSTextAlignment {
        didSet { updateTextStorage(parseText: false)}
    }
    
    open override var numberOfLines: Int {
        didSet { textContainer.maximumNumberOfLines = numberOfLines }
    }
    
    open override var lineBreakMode: NSLineBreakMode {
        didSet { textContainer.lineBreakMode = lineBreakMode }
    }
    
    // MARK: - init functions
    override public init(frame: CGRect) {
        super.init(frame: frame)
        _customizing = false
        setupLabel()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _customizing = false
        setupLabel()
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        updateTextStorage()
    }
    
    open override func drawText(in rect: CGRect) {
        let range = NSRange(location: 0, length: textStorage.length)
        
        textContainer.size = rect.size
        let newOrigin = textOrigin(inRect: rect)
        
        layoutManager.drawBackground(forGlyphRange: range, at: newOrigin)
        layoutManager.drawGlyphs(forGlyphRange: range, at: newOrigin)
    }
    
    
    // MARK: - customzation
    
    @discardableResult
    open func customize(_ block: (_ label: ActiveLabel) -> ()) -> ActiveLabel {
        _customizing = true
        block(self)
        _customizing = false
        updateTextStorage()
        return self
    }
    
    // MARK: - Auto layout
    
    open override var intrinsicContentSize: CGSize {
        guard let text = text, !text.isEmpty else {
            return .zero
        }

        textContainer.size = CGSize(width: self.preferredMaxLayoutWidth, height: CGFloat.greatestFiniteMagnitude)
        let size = layoutManager.usedRect(for: textContainer)
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
    
    // MARK: - touch events
    
    func onTouch(_ touch: UITouch) -> Bool {
        let location = touch.location(in: self)
        var avoidSuperCall = false

        switch touch.phase {
        case .began, .moved, .regionEntered, .regionMoved:
            let newElement = element(at: location)
            
            if newElement?.range != selectedElement?.range {
                updateAttributesWhenSelected(false)
                selectedElement = newElement
                updateAttributesWhenSelected(true)
                avoidSuperCall = true
            } else if newElement == nil {
                updateAttributesWhenSelected(false)
                selectedElement = nil
            }
            
        case .ended, .regionExited:
            guard let selectedElement = selectedElement else { return avoidSuperCall }
            
            switch selectedElement.element {
            case .mention(let userHandle): didTapMention(userHandle)
            case .hashtag(let hashtag): didTapHashtag(hashtag)
            case .url(let originalURL, _): didTapStringURL(originalURL)
            case .custom(let element): didTap(element, for: selectedElement.type)
            case .email(let element): didTapStringEmail(element)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.updateAttributesWhenSelected(false)
                self.selectedElement = nil
            }
            avoidSuperCall = true
            
        case .cancelled:
            updateAttributesWhenSelected(false)
            selectedElement = nil
            
        case .stationary:
            break
            
        @unknown default:
            break
        }
        
        return avoidSuperCall
    }
    
    // MARK: - private properties
    
    fileprivate var _customizing: Bool = true
    fileprivate var defaultCustomColor: UIColor = .black
    
    internal var mentionTapHandler: ((String) -> ())?
    internal var hashtagTapHandler: ((String) -> ())?
    internal var urlTapHandler: ((URL) -> ())?
    internal var emailTapHandler: ((String) -> ())?
    internal var customTapHandlers: [ActiveType : ((String) -> ())] = [:]
    
    fileprivate var mentionFilterPredicate: ((String) -> Bool)?
    fileprivate var hashtagFilterPredicate: ((String) -> Bool)?
    
    fileprivate var selectedElement: ElementTuple?
    fileprivate var heightCorrection: CGFloat = 0
    internal lazy var textStorage = NSTextStorage()
    fileprivate lazy var layoutManager = NSLayoutManager()
    fileprivate lazy var textContainer = NSTextContainer()
    lazy var activeElements = [ActiveType: [ElementTuple]]()
    
    // MARK: - helper functions
    
    fileprivate func setupLabel() {
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = lineBreakMode
        textContainer.maximumNumberOfLines = numberOfLines
        isUserInteractionEnabled = true
    }
    
    fileprivate func updateTextStorage(parseText: Bool = true) {
        if _customizing { return }
        
        // clean up previous active elements
        guard let attributedText = attributedText, attributedText.length > 0 else {
            clearActiveElements()
            textStorage.setAttributedString(NSAttributedString())
            setNeedsDisplay()
            return
        }
        
        let mutAttrString = addLineBreak(attributedText)
        
        if parseText {
            clearActiveElements()
            let newString = parseTextAndExtractActiveElements(mutAttrString)
            mutAttrString.mutableString.setString(newString)
        }
        
        addLinkAttribute(mutAttrString)
        textStorage.setAttributedString(mutAttrString)
        
        _customizing = true
        text = mutAttrString.string
        _customizing = false
        
        setNeedsDisplay()
    }
    
    fileprivate func clearActiveElements() {
        selectedElement = nil
        for (type, _) in activeElements {
            activeElements[type]?.removeAll()
        }
    }
    
    fileprivate func textOrigin(inRect rect: CGRect) -> CGPoint {
        let usedRect = layoutManager.usedRect(for: textContainer)
        heightCorrection = (rect.height - usedRect.height)/2
        let glyphOriginY = heightCorrection > 0 ? rect.origin.y + heightCorrection : rect.origin.y
        return CGPoint(x: rect.origin.x, y: glyphOriginY)
    }
    
    /// add link attribute
    fileprivate func addLinkAttribute(_ mutAttrString: NSMutableAttributedString) {
        var range = NSRange(location: 0, length: 0)
        var attributes = mutAttrString.attributes(at: 0, effectiveRange: &range)
        
        attributes[NSAttributedString.Key.font] = font!
        attributes[NSAttributedString.Key.foregroundColor] = textColor
        mutAttrString.addAttributes(attributes, range: range)
        
        attributes[NSAttributedString.Key.foregroundColor] = mentionColor
        
        for (type, elements) in activeElements {
            
            switch type {
            case .mention: attributes[NSAttributedString.Key.foregroundColor] = mentionColor
            case .hashtag: attributes[NSAttributedString.Key.foregroundColor] = hashtagColor
            case .url: attributes[NSAttributedString.Key.foregroundColor] = URLColor
            case .custom: attributes[NSAttributedString.Key.foregroundColor] = customColor[type] ?? defaultCustomColor
            case .email: attributes[NSAttributedString.Key.foregroundColor] = URLColor
            }
            
            if let highlightFont = hightlightFont {
                attributes[NSAttributedString.Key.font] = highlightFont
            }
            
            if let configureLinkAttribute = configureLinkAttribute {
                attributes = configureLinkAttribute(type, attributes, false)
            }
            
            for element in elements {
                mutAttrString.setAttributes(attributes, range: element.range)
            }
        }
    }
    
    fileprivate func parseTextAndExtractActiveElements(_ attrString: NSAttributedString) -> String {
        var textString = attrString.string
        var textRange = NSRange(location: 0, length: textString.utf16.count)
        
        if enabledTypes.contains(.url) {
            let (urlElements, finalText) = ActiveBuilder.createURLElements(from: textString, range: textRange, maximumLength: urlMaximumLength)
            textString = finalText
            textRange.length = textString.utf16.count
            activeElements[.url] = urlElements
        }
        
        enabledTypes
            .filter { $0 != .url }
            .forEach { type in
                let filter: ((String) -> Bool)? = type == .mention ? mentionFilterPredicate : (type == .hashtag ? hashtagFilterPredicate : nil)
                activeElements[type] = ActiveBuilder.createElements(type: type, from: textString, range: textRange, filterPredicate: filter)
            }
        
        return textString
    }
    
    fileprivate func addLineBreak(_ attrString: NSAttributedString) -> NSMutableAttributedString {
        let mutAttrString = NSMutableAttributedString(attributedString: attrString)
        let range = NSRange(location: 0, length: mutAttrString.length)
        
        let paragraphStyle = (mutAttrString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.minimumLineHeight = minimumLineHeight > 0 ? minimumLineHeight : font.pointSize * 1.14
        
        mutAttrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        
        return mutAttrString
    }
 
    fileprivate func updateAttributesWhenSelected(_ isSelected: Bool) {
        guard let selectedElement = selectedElement else { return }

        var attributes = textStorage.attributes(at: 0, effectiveRange: nil)
        let type = selectedElement.type

        let color: UIColor = {
            switch type {
            case .mention: return isSelected ? (mentionSelectedColor ?? mentionColor) : mentionColor
            case .hashtag: return isSelected ? (hashtagSelectedColor ?? hashtagColor) : hashtagColor
            case .url, .email: return isSelected ? (URLSelectedColor ?? URLColor) : URLColor
            case .custom:
                let customColor = customColor[type] ?? defaultCustomColor
                return isSelected ? (customSelectedColor[type] ?? customColor) : customColor
            }
        }()
        
        attributes[.foregroundColor] = color

        if let highlightFont = hightlightFont {
            attributes[.font] = highlightFont
        }

        if let configureLinkAttribute = configureLinkAttribute {
            attributes = configureLinkAttribute(type, attributes, isSelected)
        }

        textStorage.addAttributes(attributes, range: selectedElement.range)
        setNeedsDisplay()
    }
    
    fileprivate func element(at location: CGPoint) -> ElementTuple? {
        guard textStorage.length > 0 else { return nil }

        let adjustedLocation = CGPoint(x: location.x, y: location.y - heightCorrection)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: 0, length: textStorage.length), in: textContainer)
        guard boundingRect.contains(adjustedLocation) else { return nil }

        let index = layoutManager.glyphIndex(for: adjustedLocation, in: textContainer)

        return activeElements.flatMap { $0.1 }.first { element in
            index >= element.range.location && index <= element.range.location + element.range.length
        }
    }
    
    // MARK: - Handle UI Responder touches
    
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesBegan(touches, with: event)
    }
    
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesMoved(touches, with: event)
    }
    
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        _ = onTouch(touch)
        super.touchesCancelled(touches, with: event)
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if onTouch(touch) { return }
        super.touchesEnded(touches, with: event)
    }
    
    // MARK: - ActiveLabel handler
    
    fileprivate func didTapMention(_ username: String) {
        guard let mentionHandler = mentionTapHandler else {
            delegate?.didSelect(username, type: .mention)
            return
        }
        mentionHandler(username)
    }
    
    fileprivate func didTapHashtag(_ hashtag: String) {
        guard let hashtagHandler = hashtagTapHandler else {
            delegate?.didSelect(hashtag, type: .hashtag)
            return
        }
        hashtagHandler(hashtag)
    }
    
    fileprivate func didTapStringURL(_ stringURL: String) {
        guard let urlHandler = urlTapHandler, let url = URL(string: stringURL) else {
            delegate?.didSelect(stringURL, type: .url)
            return
        }
        urlHandler(url)
    }
    
    fileprivate func didTapStringEmail(_ stringEmail: String) {
        guard let emailHandler = emailTapHandler else {
            delegate?.didSelect(stringEmail, type: .email)
            return
        }
        emailHandler(stringEmail)
    }
    
    fileprivate func didTap(_ element: String, for type: ActiveType) {
        guard let elementHandler = customTapHandlers[type] else {
            delegate?.didSelect(element, type: type)
            return
        }
        elementHandler(element)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ActiveLabel: UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
