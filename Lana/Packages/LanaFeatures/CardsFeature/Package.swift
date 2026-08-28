// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CardsFeature",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "CardsFeature", targets: ["CardsFeature"])
    ],
    dependencies: [
        .package(path: "../../LanaCore"),
        .package(path: "../../LanaDesign")
    ],
    targets: [
        .target(
            name: "CardsFeature",
            dependencies: ["LanaCore", "LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "CardsFeatureTests",
            dependencies: ["CardsFeature", "LanaCore", "LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
