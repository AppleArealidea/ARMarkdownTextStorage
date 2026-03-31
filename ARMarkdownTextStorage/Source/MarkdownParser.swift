//
//  MarkdownParser.swift
//
//
//  Created by Семён C. Осипов on 16.08.2024.
//

import Foundation
import UIKit

public class MarkdownParser: NSObject {
    private var working: NSMutableAttributedString!
    private var baseFont: UIFont!
    private var baseColor: UIColor?
    
    private var defaultTextAttributes: [NSAttributedString.Key: Any]!
    
    public static func attributedString(fromMarkdown markdown: String,
                                        font: UIFont,
                                        color: UIColor? = nil,
                                        maxSymbolsCount: Int = 0) -> (attributedString: NSAttributedString, isTruncated: Bool) {
        let parser = MarkdownParser()
        
        parser.baseFont = font
        parser.baseColor = color
        
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if let color = color {
            attributes[.foregroundColor] = color
        }
        
        parser.defaultTextAttributes = attributes
        parser.working = NSMutableAttributedString(string: markdown, attributes: parser.defaultTextAttributes)
        parser.parse()
        
        var truncated = false
        if maxSymbolsCount > 0 {
            truncated = parser.substring(withMaxSymbolsCount: maxSymbolsCount)
        }
        return (parser.working, truncated)
    }
    
    private func parse() {
        let boldAttributes = createAttributesForFont(baseFont, withTrait: .traitBold)
        let italicAttributes = createAttributesForFont(baseFont, withTrait: .traitItalic)
        var strikethroughAttributes: [NSAttributedString.Key: Any] = [.strikethroughStyle: NSUnderlineStyle.thick.rawValue]
        if let color = baseColor {
            strikethroughAttributes[.kCTForegroundColor] = color.cgColor
        }
        let underlineAttributes = [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.thick.rawValue]
        
        applyParser(regex: RegularExpressionPatterns.boldRegex, attributes: boldAttributes)
        applyParser(regex: RegularExpressionPatterns.italicRegex, attributes: italicAttributes)
        applyParser(regex: RegularExpressionPatterns.strikethroughRegex, attributes: strikethroughAttributes)
        applyParser(regex: RegularExpressionPatterns.underlineRegex, attributes: underlineAttributes)
    }
    
    private func substring(withMaxSymbolsCount maxLength: Int) -> Bool {
        guard working.length > maxLength else {return false}
        let truncatedString = NSMutableAttributedString(attributedString: working.attributedSubstring(from: NSRange(location: 0, length: maxLength)))
        truncatedString.append(NSAttributedString(string: "...", attributes: defaultTextAttributes))
        working = truncatedString
        return true
    }
    
    private func applyParser(regex: NSRegularExpression, attributes: [NSAttributedString.Key: Any]) {
        var location = 0
        
        while let match = regex.firstMatch(in: working.string,
                                           options: .withoutAnchoringBounds,
                                           range: NSRange(location: location, length: working.length - location)) {
            let oldLength = working.length
            working.beginEditing()
            working.deleteCharacters(in: match.range(at: 3))
            working.enumerateAttributes(in: match.range(at: 2), options: .longestEffectiveRangeNotRequired, using: { dictionary, range, _ in
                if let appliesFont = attributes[NSAttributedString.Key.font] as? UIFont,
                   let currentFont = dictionary[NSAttributedString.Key.font] as? UIFont {
                    let newFont = fontWithBoldTrait(appliesFont.isBold || currentFont.isBold,
                                                    italicTrait: appliesFont.isItalic || currentFont.isItalic,
                                                    fontName: appliesFont.familyName,
                                                    fontSize: appliesFont.pointSize)
                    working.addAttribute(NSAttributedString.Key.font, value: newFont, range: range)
                } else {
                    working.addAttributes(attributes, range: range)
                }
            })
            working.deleteCharacters(in: match.range(at: 1))
            working.endEditing()
            let newLength = working.length
            location = match.range.location + match.range.length + newLength - oldLength
        }
    }
}
