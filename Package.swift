// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ARMarkdownTextStorage",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "ARMarkdownTextStorage",
            targets: ["ARMarkdownTextStorage"]),
    ],
    targets: [
        .target(
            name: "ARMarkdownTextStorage",
            path: "ARMarkdownTextStorage/Source"),
        .testTarget(
            name: "ARMarkdownTextStorageTests",
            dependencies: ["ARMarkdownTextStorage"],
            path: "Tests/ARMarkdownTextStorageTests")
    ]
)
