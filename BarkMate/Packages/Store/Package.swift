// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Store",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "Store", targets: ["Store"])
    ],
    dependencies: [
        .package(path: "../Models")
    ],
    targets: [
        .target(
            name: "Store",
            dependencies: ["Models"],
            path: "Sources/Store"
        ),
        .testTarget(
            name: "StoreTests",
            dependencies: ["Store"],
            path: "Tests/StoreTests"
        )
    ]
)
