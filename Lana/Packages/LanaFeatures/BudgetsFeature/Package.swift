// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BudgetsFeature",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "BudgetsFeature", targets: ["BudgetsFeature"])
    ],
    dependencies: [
        .package(path: "../../LanaCore"),
        .package(path: "../../LanaDesign")
    ],
    targets: [
        .target(
            name: "BudgetsFeature",
            dependencies: ["LanaCore", "LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "BudgetsFeatureTests",
            dependencies: ["BudgetsFeature"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
