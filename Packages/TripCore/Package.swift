// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TripCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TripCore",
            targets: ["TripCore"]
        ),
    ],
    targets: [
        .target(
            name: "TripCore"
        ),
        .testTarget(
            name: "TripCoreTests",
            dependencies: ["TripCore"]
        ),
    ]
)
