// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftOpenAICLI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "swiftopenai",
            targets: ["SwiftOpenAICLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/jamesrochabrun/SwiftOpenAI.git", from: "2.9.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "4.1.0"),
        .package(url: "https://github.com/scottrhoyt/SwiftyTextTable.git", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "SwiftOpenAICLI",
            dependencies: [
                .product(name: "SwiftOpenAI", package: "SwiftOpenAI"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Rainbow", package: "Rainbow"),
                .product(name: "SwiftyTextTable", package: "SwiftyTextTable"),
                .product(name: "Markdown", package: "swift-markdown")
            ]
        ),
        .testTarget(
            name: "SwiftOpenAICLITests",
            dependencies: ["SwiftOpenAICLI"]
        )
    ]
)