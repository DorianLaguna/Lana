// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DashboardFeature",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "DashboardFeature", targets: ["DashboardFeature"])
    ],
    dependencies: [
        .package(path: "../../LanaCore"),
        .package(path: "../../LanaDesign")
    ],
    targets: [
        .target(
            name: "DashboardFeature",
            dependencies: ["LanaCore", "LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "DashboardFeatureTests",
            dependencies: ["DashboardFeature"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
