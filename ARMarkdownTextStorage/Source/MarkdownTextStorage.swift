//
//  MarkdownTextStorage.swift
//
//
//  Created by Семён C. Осипов on 16.08.2024.
//

import Foundation
import UIKit

@objc public class MarkdownTextStorage: NSTextStorage {
    @objc let backingStore = NSMutableAttributedString()
    
    private var highlighters: [RegularExpressionHighlighter]!
    private var normalFont: UIFont
    
    @objc public init(font: UIFont) {
        normalFont = font
        super.init()
        createHighlightPatterns()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override public func attributes(at location: Int,
                                    effectiveRange range: NSRangePointer? ) -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }
    
    override public func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters,
               range: range,
               changeInLength: (str as NSString).length - range.length)
        endEditing()
    }
    
    override public func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }
    
    override public func processEditing() {
        performReplacementsForRange(changedRange: editedRange)
        super.processEditing()
    }
    
    public override var string: String {
        self.backingStore.string
    }
    
    private func performReplacementsForRange(changedRange: NSRange) {
        var extendedRange = NSUnionRange(
            changedRange,
            NSString(string: backingStore.string)
                .lineRange(for: NSRange(location: changedRange.location, length: 0))
        )
        extendedRange = NSUnionRange(
            changedRange,
            NSString(string: backingStore.string)
                .lineRange(for: NSRange(location: NSMaxRange(changedRange), length: 0))
        )
        applyStylesToRange(searchRange: extendedRange)
    }
    
    func applyStylesToRange(searchRange: NSRange) {
        let normalAttrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: normalFont,
            NSAttributedString.Key.strikethroughStyle: 0,
            NSAttributedString.Key.underlineStyle: 0
        ]
        addAttributes(normalAttrs, range: searchRange)
        
        guard !backingStore.string.hasPrefix("@@") else { return }
        
        for highlighter in highlighters {
            do {
                let regex = try NSRegularExpression(pattern: highlighter.pattern)
                regex.enumerateMatches(in: backingStore.string, range: searchRange) { match, _, _ in
                    if let matchRange = match?.range(at: 0) {
                        enumerateAttributes(in: matchRange, options: .longestEffectiveRangeNotRequired, using: { dictionary, range, _ in
                            if let appliesFont = highlighter.attributes[NSAttributedString.Key.font] as? UIFont,
                                let currentFont = dictionary[NSAttributedString.Key.font] as? UIFont {
                                let newFont = fontWithBoldTrait(appliesFont.isBold || currentFont.isBold,
                                                                italicTrait: appliesFont.isItalic || appliesFont.isItalic,
                                                                fontName: appliesFont.familyName,
                                                                fontSize: appliesFont.pointSize)
                                addAttribute(NSAttributedString.Key.font, value: newFont, range: range)
                            } else {
                                addAttributes(highlighter.attributes, range: range)
                            }
                        })
                        
                        let maxRange = matchRange.location + matchRange.length
                        if maxRange + 1 < length {
                            addAttributes(normalAttrs, range: NSRange(location: maxRange, length: 1))
                        }
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    private func createHighlightPatterns() {
        let boldAttributes = createAttributesForFont(normalFont, withTrait: .traitBold)
        let italicAttributes = createAttributesForFont(normalFont, withTrait: .traitItalic)
        let strikethroughAttributes = [NSAttributedString.Key.strikethroughStyle: 2]
        let underlineAttributes = [NSAttributedString.Key.underlineStyle: 2]
        
        highlighters = [
            RegularExpressionHighlighter(pattern: RegularExpressionPatterns.bold, attributes: boldAttributes),
            RegularExpressionHighlighter(pattern: RegularExpressionPatterns.italic, attributes: italicAttributes),
            RegularExpressionHighlighter(pattern: RegularExpressionPatterns.strikethrough, attributes: strikethroughAttributes),
            RegularExpressionHighlighter(pattern: RegularExpressionPatterns.underline, attributes: underlineAttributes)
        ]
    }
    
    public func setDefaultFont(_ font: UIFont) {
        normalFont = font
        edited(.editedAttributes, range: NSRange(location: 0, length: backingStore.length), changeInLength: 0)
    }
}
