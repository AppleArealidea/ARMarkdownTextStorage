//
//  MarkdownTextStorage.swift
//
//
//  Created by Семён C. Осипов on 16.08.2024.
//

import Foundation
import UIKit

@objc public class MarkdownTextStorage: NSTextStorage {
    private let backingStore = NSMutableAttributedString()
    private var cachedString: String?
    
    private var highlighters: [RegularExpressionHighlighter]!
    private var normalFont: UIFont
    
    /// Spell-check underlines commonly use `.single`; markdown `` `...` `` underline uses `.double` to avoid collisions.
    private static let markdownUnderlineStyleRaw = Int(NSUnderlineStyle.double.rawValue)
    
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
        cachedString = nil
        performReplacementsForRange(changedRange: editedRange)
        super.processEditing()
    }
    
    public override var string: String {
        if let cached = cachedString {
            return cached
        }
        let newString = backingStore.string
        cachedString = newString
        return newString
    }
    
    private func performReplacementsForRange(changedRange: NSRange) {
        var extendedRange = NSUnionRange(
            changedRange,
            NSString(string: backingStore.string)
                .lineRange(for: NSRange(location: changedRange.location, length: 0))
        )
        extendedRange = NSUnionRange(
            extendedRange,
            NSString(string: backingStore.string)
                .lineRange(for: NSRange(location: NSMaxRange(changedRange), length: 0))
        )
        applyStylesToRange(searchRange: extendedRange)
    }
    
    func applyStylesToRange(searchRange: NSRange) {
        // Reset font/strikethrough only where markdown regex does not cover the text, and only
        // if values actually differ. A full-line `addAttributes` forces `editedAttributes` on
        // the entire line and strips UITextView spell-check presentation (often temporary
        // NSLayoutManager attributes tied to invalidations).
        let baseResetAttrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: normalFont,
            NSAttributedString.Key.strikethroughStyle: 0,
        ]
        
        if backingStore.string.hasPrefix("@@") {
            addAttributes(baseResetAttrs, range: searchRange)
            clearStaleMarkdownUnderline(in: searchRange)
            return
        }
        
        applyBaseResetOutsideHighlighterMatches(searchRange: searchRange, baseResetAttrs: baseResetAttrs)
        clearStaleMarkdownUnderline(in: searchRange)
        
        for highlighter in highlighters {
            highlighter.regex.enumerateMatches(in: backingStore.string, range: searchRange) { match, _, _ in
                if let matchRange = match?.range(at: 0) {
                    self.enumerateAttributes(in: matchRange, options: .longestEffectiveRangeNotRequired, using: { dictionary, range, _ in
                        if let appliesFont = highlighter.attributes[NSAttributedString.Key.font] as? UIFont,
                            let currentFont = dictionary[NSAttributedString.Key.font] as? UIFont {
                            let newFont = fontWithBoldTrait(appliesFont.isBold || currentFont.isBold,
                                                            italicTrait: appliesFont.isItalic || currentFont.isItalic,
                                                            fontName: appliesFont.familyName,
                                                            fontSize: appliesFont.pointSize)
                            if !self.fontsMatchForHighlighterApplication(newFont, currentFont) {
                                self.addAttribute(NSAttributedString.Key.font, value: newFont, range: range)
                            }
                        } else {
                            if !self.dictionaryContainsAttributes(highlighter.attributes, range: range) {
                                self.addAttributes(highlighter.attributes, range: range)
                            }
                        }
                    })
                    
                    let maxRange = matchRange.location + matchRange.length
                    if maxRange + 1 < self.length {
                        self.applyBaseResetIfNeeded(
                            range: NSRange(location: maxRange, length: 1),
                            baseResetAttrs: baseResetAttrs
                        )
                    }
                }
            }
        }
    }
    
    private func clearStaleMarkdownUnderline(in searchRange: NSRange) {
        guard searchRange.length > 0 else { return }
        let liveMarkdownUnderlineRanges = matchRanges(for: RegularExpressionPatterns.underlineRegex, in: searchRange)
        let mdRaw = Self.markdownUnderlineStyleRaw
        enumerateAttribute(.underlineStyle, in: searchRange, options: []) { value, range, _ in
            let raw = (value as? NSNumber)?.intValue ?? (value as? Int) ?? 0
            guard raw == mdRaw else { return }
            let clamped = NSIntersectionRange(range, searchRange)
            guard clamped.length > 0 else { return }
            for stale in rangesBySubtractingMatchUnion(from: clamped, matches: liveMarkdownUnderlineRanges) {
                guard stale.length > 0 else { continue }
                let staleAttrs = attributes(at: stale.location, effectiveRange: nil)
                let cur = (staleAttrs[.underlineStyle] as? NSNumber)?.intValue
                    ?? (staleAttrs[.underlineStyle] as? Int) ?? 0
                guard cur == mdRaw else { continue }
                addAttribute(.underlineStyle, value: 0, range: stale)
            }
        }
    }
    
    private func matchRanges(for regex: NSRegularExpression, in searchRange: NSRange) -> [NSRange] {
        var ranges: [NSRange] = []
        regex.enumerateMatches(in: backingStore.string, options: [], range: searchRange) { match, _, _ in
            if let r = match?.range(at: 0) { ranges.append(r) }
        }
        return ranges
    }
    
    private func rangesBySubtractingMatchUnion(from range: NSRange, matches: [NSRange]) -> [NSRange] {
        guard range.length > 0 else { return [] }
        let relevant = matches
            .map { NSIntersectionRange(range, $0) }
            .filter { $0.length > 0 }
            .sorted { $0.location < $1.location }
        guard !relevant.isEmpty else { return [range] }
        var merged: [NSRange] = []
        for r in relevant {
            if let last = merged.last, NSMaxRange(last) >= r.location {
                merged[merged.count - 1] = NSUnionRange(last, r)
            } else {
                merged.append(r)
            }
        }
        var result: [NSRange] = []
        var cursor = range.location
        let rangeEnd = NSMaxRange(range)
        for m in merged {
            if cursor < m.location {
                result.append(NSRange(location: cursor, length: m.location - cursor))
            }
            cursor = max(cursor, NSMaxRange(m))
        }
        if cursor < rangeEnd {
            result.append(NSRange(location: cursor, length: rangeEnd - cursor))
        }
        return result
    }
    
    private func mergedHighlighterMatchRanges(in searchRange: NSRange) -> [NSRange] {
        var collect: [NSRange] = []
        for h in highlighters {
            h.regex.enumerateMatches(in: backingStore.string, options: [], range: searchRange) { match, _, _ in
                if let r = match?.range(at: 0), r.length > 0 {
                    collect.append(r)
                }
            }
        }
        guard !collect.isEmpty else { return [] }
        let sorted = collect.sorted { $0.location < $1.location }
        var merged: [NSRange] = []
        for r in sorted {
            if let last = merged.last, NSMaxRange(last) >= r.location {
                merged[merged.count - 1] = NSUnionRange(last, r)
            } else {
                merged.append(r)
            }
        }
        return merged
    }
    
    private func applyBaseResetOutsideHighlighterMatches(
        searchRange: NSRange,
        baseResetAttrs: [NSAttributedString.Key: Any]
    ) {
        guard searchRange.length > 0 else { return }
        let merged = mergedHighlighterMatchRanges(in: searchRange)
        let outsideChunks = rangesBySubtractingMatchUnion(from: searchRange, matches: merged)
        for chunk in outsideChunks {
            var idx = chunk.location
            let end = NSMaxRange(chunk)
            while idx < end {
                var eff = NSRange()
                _ = attributes(at: idx, effectiveRange: &eff)
                let clamped = NSIntersectionRange(eff, chunk)
                guard clamped.length > 0 else { break }
                let chunkAttrs = attributes(at: clamped.location, effectiveRange: nil)
                let font = chunkAttrs[.font] as? UIFont
                let strike = (chunkAttrs[.strikethroughStyle] as? NSNumber)?.intValue ?? (chunkAttrs[.strikethroughStyle] as? Int) ?? 0
                if needsMarkdownBaseReset(currentFont: font, strikeRaw: strike) {
                    addAttributes(baseResetAttrs, range: clamped)
                }
                idx = NSMaxRange(clamped)
            }
        }
    }
    
    private func applyBaseResetIfNeeded(
        range: NSRange,
        baseResetAttrs: [NSAttributedString.Key: Any]
    ) {
        guard range.length > 0 else { return }
        let attrs = attributes(at: range.location, effectiveRange: nil)
        let font = attrs[.font] as? UIFont
        let strike = (attrs[.strikethroughStyle] as? NSNumber)?.intValue ?? (attrs[.strikethroughStyle] as? Int) ?? 0
        if needsMarkdownBaseReset(currentFont: font, strikeRaw: strike) {
            addAttributes(baseResetAttrs, range: range)
        }
    }
    
    /// UITextView typing often uses a body font instance that is not `==` to `normalFont.fontDescriptor`
    /// even when point size and bold/italic match — avoid useless `editedAttributes` churn.
    private func fontsMatchBodyBase(_ a: UIFont, _ b: UIFont) -> Bool {
        let ta = a.fontDescriptor.symbolicTraits.intersection([.traitBold, .traitItalic])
        let tb = b.fontDescriptor.symbolicTraits.intersection([.traitBold, .traitItalic])
        return abs(a.pointSize - b.pointSize) < 0.01 && ta == tb
    }
    
    private func fontsMatchForHighlighterApplication(_ a: UIFont, _ b: UIFont) -> Bool {
        abs(a.pointSize - b.pointSize) < 0.01 && a.fontDescriptor.symbolicTraits == b.fontDescriptor.symbolicTraits
    }
    
    private func intFromAttributeValue(_ v: Any?) -> Int? {
        if let n = v as? NSNumber { return n.intValue }
        if let i = v as? Int { return i }
        return nil
    }
    
    private func dictionaryContainsAttributes(_ desired: [NSAttributedString.Key: Any], range: NSRange) -> Bool {
        guard range.length > 0 else { return true }
        let cur = attributes(at: range.location, effectiveRange: nil)
        for (key, wantVal) in desired {
            switch key {
            case .font:
                guard let want = wantVal as? UIFont, let have = cur[key] as? UIFont else { return false }
                if !fontsMatchForHighlighterApplication(want, have) { return false }
            case .strikethroughStyle, .underlineStyle:
                guard let w = intFromAttributeValue(wantVal) else { return false }
                let h = intFromAttributeValue(cur[key]) ?? 0
                if w != h { return false }
            default:
                return false
            }
        }
        return true
    }
    
    private func needsMarkdownBaseReset(currentFont: UIFont?, strikeRaw: Int) -> Bool {
        if strikeRaw != 0 { return true }
        guard let f = currentFont else { return true }
        return !fontsMatchBodyBase(f, normalFont)
    }

    private func createHighlightPatterns() {
        let boldAttributes = createAttributesForFont(normalFont, withTrait: .traitBold)
        let italicAttributes = createAttributesForFont(normalFont, withTrait: .traitItalic)
        let strikethroughAttributes = [NSAttributedString.Key.strikethroughStyle: 2]
        let underlineAttributes = [NSAttributedString.Key.underlineStyle: Self.markdownUnderlineStyleRaw]
        
        highlighters = [
            RegularExpressionHighlighter(regex: RegularExpressionPatterns.boldRegex, attributes: boldAttributes),
            RegularExpressionHighlighter(regex: RegularExpressionPatterns.italicRegex, attributes: italicAttributes),
            RegularExpressionHighlighter(regex: RegularExpressionPatterns.strikethroughRegex, attributes: strikethroughAttributes),
            RegularExpressionHighlighter(regex: RegularExpressionPatterns.underlineRegex, attributes: underlineAttributes)
        ]
    }
    
    public func setDefaultFont(_ font: UIFont) {
        normalFont = font
        createHighlightPatterns()
        beginEditing()
        edited(.editedAttributes, range: NSRange(location: 0, length: backingStore.length), changeInLength: 0)
        endEditing()
    }
}
