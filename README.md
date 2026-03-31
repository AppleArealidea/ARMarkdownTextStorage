# ARMarkdownTextStorage

A lightweight Swift library for live markdown-style highlighting and parsing in iOS apps, built on top of `NSTextStorage`.

## Features

- **Live highlighting** via `MarkdownTextStorage` — attach to any `UITextView` for real-time styling without removing markup characters
- **Static parsing** via `MarkdownParser` — convert a markdown string into `NSAttributedString` with markup characters stripped
- Combinable styles (e.g. bold + italic in the same range)
- Optional text truncation with `"..."` suffix
- Disable highlighting for a specific text by prefixing it with `@@`

## Supported Syntax

| Style | Markup | Example |
|---|---|---|
| **Bold** | `**text**` | `**hello**` |
| *Italic* | `__text__` | `__hello__` |
| ~~Strikethrough~~ | `~~text~~` | `~~hello~~` |
| Underline | `` ```text``` `` | `` ```hello``` `` |

## Requirements

- iOS 13.0+
- Swift 5.10+
- Xcode 15+

## Installation

### Swift Package Manager

In Xcode, go to **File > Add Package Dependencies…** and enter the repository URL:

```
https://github.com/AppleArealidea/ARMarkdownTextStorage.git
```

Or add it to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/AppleArealidea/ARMarkdownTextStorage.git", from: "1.0.0")
]
```

Then add `"ARMarkdownTextStorage"` to the `dependencies` of your target.

## Usage

### Live Highlighting with UITextView

Use `MarkdownTextStorage` to add real-time markdown highlighting to a `UITextView`. Markup characters remain visible in the text while their content is styled.

```swift
import ARMarkdownTextStorage

let font = UIFont.systemFont(ofSize: 16)
let textStorage = MarkdownTextStorage(font: font)

let layoutManager = NSLayoutManager()
textStorage.addLayoutManager(layoutManager)

let textContainer = NSTextContainer(size: view.bounds.size)
layoutManager.addTextContainer(textContainer)

let textView = UITextView(frame: view.bounds, textContainer: textContainer)
view.addSubview(textView)
```

To update the base font later:

```swift
textStorage.setDefaultFont(UIFont.systemFont(ofSize: 20))
```

### Parsing Markdown to NSAttributedString

Use `MarkdownParser` to convert a markdown string into a styled `NSAttributedString` with all markup characters removed.

```swift
import ARMarkdownTextStorage

let input = "**Bold** and __italic__ with ~~strikethrough~~"
let font = UIFont.systemFont(ofSize: 16)

let (attributedString, isTruncated) = MarkdownParser.attributedString(
    fromMarkdown: input,
    font: font
)
```

With optional text color and max length:

```swift
let (attributedString, isTruncated) = MarkdownParser.attributedString(
    fromMarkdown: input,
    font: font,
    color: .label,
    maxSymbolsCount: 100
)
```

## License

This project is available under the MIT license. See the [LICENSE](LICENSE) file for details.
