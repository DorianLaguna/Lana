// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OnboardingFeature",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"])
    ],
    dependencies: [
        .package(path: "../../LanaCore"),
        .package(path: "../../LanaDesign")
    ],
    targets: [
        .target(
            name: "OnboardingFeature",
            dependencies: ["LanaCore", "LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "OnboardingFeatureTests",
            dependencies: ["OnboardingFeature", "LanaCore", "LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
