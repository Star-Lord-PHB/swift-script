// swift-tools-version: 6.0.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-script-runner",
    platforms: [.macOS("15.1.0")],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", "1.1.4" ..< "2.0.0"),.package(url: "https://github.com/apple/swift-system.git", "1.3.0" ..< "2.0.0"),.package(url: "https://github.com/apple/swift-async-algorithms.git", "1.0.2" ..< "2.0.0"),.package(url: "https://github.com/apple/swift-log.git", "1.6.1" ..< "2.0.0"),.package(url: "https://github.com/apple/swift-numerics.git", "1.0.2" ..< "2.0.0"),.package(url: "https://github.com/apple/swift-argument-parser.git", "1.5.0" ..< "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "Runner",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),.product(name: "DequeModule", package: "swift-collections"),.product(name: "OrderedCollections", package: "swift-collections"),.product(name: "SystemPackage", package: "swift-system"),.product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),.product(name: "Logging", package: "swift-log"),.product(name: "ComplexModule", package: "swift-numerics"),.product(name: "Numerics", package: "swift-numerics"),.product(name: "RealModule", package: "swift-numerics"),.product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
    ]
)