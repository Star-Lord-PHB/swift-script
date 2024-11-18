// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "swift-script",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/Star-Lord-PHB/FoundationPlus.git", from: "0.1.0"),
        .package(url: "https://github.com/Zollerboy1/SwiftCommand.git", from: "1.4.1"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1"),
        .package(url: "https://github.com/Star-Lord-PHB/swift-codable-macro.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", branch: "main"),],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "SwiftScript",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "FoundationPlus", package: "FoundationPlus"),
                .product(name: "SwiftCommand", package: "swiftcommand"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "CodableMacro", package: "swift-codable-macro"),]),
        .testTarget(
            name: "SwiftScriptTest",
            dependencies: [
                "SwiftScript",
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "SwiftCommand", package: "swiftcommand"),],
            resources: [.copy("AppFolderTemplates")]),
    ]
)
