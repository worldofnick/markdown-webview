// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "markdown-webview",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "MarkdownWebView",
            targets: ["MarkdownWebView"]
        )
    ],
    targets: [
        .target(
            name: "MarkdownWebView",
            resources: [
                .copy("Resources/template.html"),
                .copy("Resources/script.js"),
                .copy("Resources/markdown-it-bundle.js"),
                .copy("Resources/default-macOS.css"),
                .copy("Resources/default-iOS.css"),
                .copy("Resources/github-markdown.css"),
                .copy("Resources/katex.css"),
                .copy("Resources/texmath.css"),
            ]
        )
    ]
)
