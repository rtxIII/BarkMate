// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BarkService",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "BarkService", targets: ["BarkService"])
    ],
    dependencies: [
        .package(path: "../Models"),
        .package(path: "../Store"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0")
    ],
    targets: [
        .target(
            name: "BarkService",
            dependencies: ["Models", "Store", "CryptoSwift"],
            path: "Sources/BarkService"
        ),
        .testTarget(
            name: "BarkServiceTests",
            dependencies: ["BarkService"],
            path: "Tests/BarkServiceTests"
        )
    ]
)
