// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SharedFeature",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SharedFeature", targets: ["SharedFeature"])
    ],
    dependencies: [
        .package(path: "../../LanaCore"),
        .package(path: "../../LanaDesign")
    ],
    targets: [
        .target(
            name: "SharedFeature",
            dependencies: ["LanaCore", "LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "SharedFeatureTests",
            dependencies: ["SharedFeature", "LanaCore", "LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
