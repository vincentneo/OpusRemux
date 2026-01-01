// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpusRemux",
    platforms: [
        .iOS(.v14),
        .watchOS(.v8),
        .tvOS(.v14),
        .macOS(.v11),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OpusRemux",
            targets: ["OpusRemux"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vincentneo/SwiftOgg.git", from: "1.3.5")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OpusRemux",
            dependencies: [
                .product(name: "COgg", package: "SwiftOgg")
            ]
        ),
    ]
)
