// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LanaInsights",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LanaInsights", targets: ["LanaInsights"])
    ],
    dependencies: [
        .package(path: "../LanaCore")
    ],
    targets: [
        .target(
            name: "LanaInsights",
            dependencies: ["LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "LanaInsightsTests",
            dependencies: ["LanaInsights", "LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
