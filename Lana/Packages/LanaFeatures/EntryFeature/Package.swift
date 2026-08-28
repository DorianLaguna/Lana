// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EntryFeature",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "EntryFeature", targets: ["EntryFeature"])
    ],
    dependencies: [
        .package(path: "../../LanaCore"),
        .package(path: "../../LanaDesign")
    ],
    targets: [
        .target(
            name: "EntryFeature",
            dependencies: ["LanaCore", "LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "EntryFeatureTests",
            dependencies: ["EntryFeature"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
