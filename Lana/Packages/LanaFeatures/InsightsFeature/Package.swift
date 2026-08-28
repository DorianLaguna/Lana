// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "InsightsFeature",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "InsightsFeature", targets: ["InsightsFeature"])
    ],
    dependencies: [
        .package(path: "../../LanaCore"),
        .package(path: "../../LanaDesign")
    ],
    targets: [
        .target(
            name: "InsightsFeature",
            dependencies: ["LanaCore", "LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "InsightsFeatureTests",
            dependencies: ["InsightsFeature"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
