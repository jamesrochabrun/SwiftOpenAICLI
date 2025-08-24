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
        ),
        .library(
            name: "SwiftOpenAICLICore",
            targets: ["SwiftOpenAICLICore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/jamesrochabrun/SwiftOpenAI.git", from: "4.3.2"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "4.1.0"),
        .package(url: "https://github.com/scottrhoyt/SwiftyTextTable.git", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.6.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.1")
    ],
    targets: [
        .executableTarget(
            name: "SwiftOpenAICLI",
            dependencies: [
                "SwiftOpenAICLICore"
            ],
            path: "Sources/SwiftOpenAICLI"
        ),
        .target(
            name: "SwiftOpenAICLICore",
            dependencies: [
                .product(name: "SwiftOpenAI", package: "SwiftOpenAI"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Rainbow", package: "Rainbow"),
                .product(name: "SwiftyTextTable", package: "SwiftyTextTable"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/SwiftOpenAICLICore"
        ),
        .testTarget(
            name: "SwiftOpenAICLITests",
            dependencies: ["SwiftOpenAICLICore"]
        )
    ]
)