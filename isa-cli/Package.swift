// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "ISA",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    .package(path: "../"),  // SwiftOpenAICLI local package
    .package(url: "https://github.com/jamesrochabrun/SwiftOpenAI", from: "4.3.2"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.0"),
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
  ],
  targets: [
    .executableTarget(
      name: "ISA",
      dependencies: [
        .product(name: "SwiftOpenAICLICore", package: "SwiftOpenAICLI"),
        .product(name: "SwiftOpenAI", package: "SwiftOpenAI"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Rainbow", package: "Rainbow"),
        .product(name: "Yams", package: "Yams")
      ],
      path: "Sources/ISA"
    ),
    .testTarget(
      name: "ISATests",
      dependencies: ["ISA"]
    )
  ]
)