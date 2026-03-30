// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MiniChart",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MiniChart",
            targets: ["MiniChart"]
        )
    ],
    targets: [
        .target(
            name: "MiniChart"
        ),
        .testTarget(
            name: "MiniChartTests",
            dependencies: ["MiniChart"]
        )
    ]
)
