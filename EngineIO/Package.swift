// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EngineIO",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "EngineIO", targets: ["EngineIO"])
    ],
    targets: [
        .target(name: "EngineIO"),
        .testTarget(name: "EngineIOTests", dependencies: ["EngineIO"])
    ]
)
