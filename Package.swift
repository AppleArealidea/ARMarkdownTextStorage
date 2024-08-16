// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ARMarkdownTextStorage",
    products: [
        .library(
            name: "ARMarkdownTextStorage",
            targets: ["ARMarkdownTextStorage"]),
    ],
    targets: [
        .target(
            name: "ARMarkdownTextStorage",
            path: "ARMarkdownTextStorage/Source")
    ]
)
