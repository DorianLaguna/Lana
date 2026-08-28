// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SettingsFeature",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SettingsFeature", targets: ["SettingsFeature"])
    ],
    dependencies: [
        .package(path: "../../LanaCore"),
        .package(path: "../../LanaDesign")
    ],
    targets: [
        .target(
            name: "SettingsFeature",
            dependencies: ["LanaCore", "LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "SettingsFeatureTests",
            dependencies: ["SettingsFeature", "LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
