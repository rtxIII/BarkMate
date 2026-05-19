// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MemoKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "MemoKit", targets: ["MemoKit"])
    ],
    dependencies: [
        .package(path: "../Models"),
        .package(path: "../Store")
    ],
    targets: [
        .target(
            name: "MemoKit",
            dependencies: ["Models", "Store"],
            path: "Sources/MemoKit"
        )
    ]
)
