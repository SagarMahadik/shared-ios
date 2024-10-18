// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "shared",
    platforms: [
        .macOS("13.1"),
        .iOS("16.4"),
        // .watchOS(.v6),
        // .tvOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "shared",
            targets: ["shared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git",from : "5.26.1"),
        .package(url: "https://github.com/Flight-School/AnyCodable.git",from : "0.6.7"),
        .package(url: "https://github.com/LaunchDarkly/swift-eventsource.git", .upToNextMajor(from: "3.3.0"))
        
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "shared",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "LDSwiftEventSource", package: "swift-eventsource")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "sharedTests",
            dependencies: ["shared"]),
    ]
)
