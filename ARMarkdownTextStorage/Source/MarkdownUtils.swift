//
//  MarkdownUtils.swift
//
//
//  Created by Семён C. Осипов on 16.08.2024.
//

import Foundation
import UIKit

func createAttributesForFont(
    _ font: UIFont,
    withTrait trait: UIFontDescriptor.SymbolicTraits
) -> [NSAttributedString.Key: Any] {
    let fontDescriptor = font.fontDescriptor
    let descriptorWithTrait = fontDescriptor.withSymbolicTraits(trait)
    let font = UIFont(descriptor: descriptorWithTrait!, size: 0)
    return [.font: font]
}

func fontWithBoldTrait(
    _ isBold: Bool,
    italicTrait isItalic: Bool,
    fontName: String,
    fontSize: CGFloat
) -> UIFont {
    let font = UIFont(name: fontName, size: fontSize)!
    let fontDescriptor = font.fontDescriptor
    
    var traits = UIFontDescriptor.SymbolicTraits(rawValue: 0)
    if isBold {
        traits.insert(.traitBold)
    }
    if isItalic {
        traits.insert(.traitItalic)
    }
    
    let descriptorWithTrait = fontDescriptor.withSymbolicTraits(traits)
    return UIFont(descriptor: descriptorWithTrait!, size: fontSize)
}

public struct RegularExpressionPatterns {
    public static let boldSymbol = "**"
    public static let italicSymbol = "__"
    public static let strikethroughSymbol = "~~"
    public static let underlineSymbol = "```"
    
    static let bold = "(\\*\\*)(.+?)(\\1)"
    static let italic = "(\(italicSymbol))(.+?)(\\1)"
    static let strikethrough = "(\(strikethroughSymbol))(.+?)(\\1)"
    static let underline = "(\(underlineSymbol))(.+?)(\\1)"
}

struct RegularExpressionHighlighter {
    let pattern: String
    let attributes: [NSAttributedString.Key: Any]
}

extension NSAttributedString.Key {
    static let kCTForegroundColor = NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String)
}

extension UIFont {
    public var isBold: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitBold)
    }

    public var isItalic: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
}
