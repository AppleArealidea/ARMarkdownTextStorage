//
//  MarkdownTextStorageRangeSafetyTests.swift
//  ARMarkdownTextStorageTests
//
//  Regression tests for the out-of-bounds NSRangeException crash
//  (Crashlytics d74fde1b / 60ed0e74) thrown when the UIKit text-input
//  subsystem passes a range whose end exceeds the backing store length.
//

import UIKit
import XCTest
@testable import ARMarkdownTextStorage

final class MarkdownTextStorageRangeSafetyTests: XCTestCase {
    private func makeStorage() -> MarkdownTextStorage {
        MarkdownTextStorage(font: UIFont.preferredFont(forTextStyle: .body))
    }

    // 1. Replacement range whose end is past the content is clamped, not crashing.
    func test_replaceCharacters_rangeBeyondLength_isClampedAndAppends() {
        let storage = makeStorage()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "abc")

        storage.replaceCharacters(in: NSRange(location: 5, length: 10), with: "x")

        XCTAssertEqual(storage.string, "abcx")
    }

    // 2. Deletion longer than the content empties the store without crashing.
    func test_replaceCharacters_deleteMoreThanLength_emptiesStore() {
        let storage = makeStorage()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "abc")

        storage.replaceCharacters(in: NSRange(location: 0, length: 99), with: "")

        XCTAssertEqual(storage.string, "")
    }

    // 3. Negative / oversized location passed to replace is tolerated.
    func test_replaceCharacters_negativeLocation_doesNotCrash() {
        let storage = makeStorage()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "abc")

        storage.replaceCharacters(in: NSRange(location: -3, length: 2), with: "Z")

        XCTAssertFalse(storage.string.isEmpty)
    }

    // 4. attributes(at:) past the end does not crash.
    func test_attributes_locationBeyondLength_doesNotCrash() {
        let storage = makeStorage()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "abc")

        _ = storage.attributes(at: 99, effectiveRange: nil)
    }

    // 5. attributes(at:) on an empty store returns empty attributes, no crash.
    func test_attributes_onEmptyStore_returnsEmpty() {
        let storage = makeStorage()

        let attrs = storage.attributes(at: 0, effectiveRange: nil)

        XCTAssertTrue(attrs.isEmpty)
    }

    // 6. setAttributes with an out-of-bounds range is clamped, no crash.
    func test_setAttributes_rangeBeyondLength_doesNotCrash() {
        let storage = makeStorage()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "abc")

        storage.setAttributes([.foregroundColor: UIColor.red], range: NSRange(location: 1, length: 50))

        XCTAssertEqual(storage.string, "abc")
    }

    // 7. Sanity: normal in-bounds editing still behaves correctly.
    func test_replaceCharacters_inBounds_behavesNormally() {
        let storage = makeStorage()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "hello")
        storage.replaceCharacters(in: NSRange(location: 0, length: 5), with: "world")

        XCTAssertEqual(storage.string, "world")
    }
}
