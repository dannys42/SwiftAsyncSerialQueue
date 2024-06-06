// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var swiftSettings: [SwiftSetting] = [
    // Do not release with this enabled as upstream packages will not be able to import
//
//    .unsafeFlags([
//        "-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks",
//    ])
]

let package = Package(
    name: "SwiftAsyncSerialQueue",
    platforms: [ .iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9) ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AsyncSerialQueue",
            targets: ["AsyncSerialQueue"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AsyncSerialQueue",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AsyncSerialQueueTests",
            dependencies: ["AsyncSerialQueue"],
            swiftSettings: swiftSettings
        ),
    ]
)
