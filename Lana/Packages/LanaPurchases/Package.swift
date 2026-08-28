// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LanaPurchases",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LanaPurchases", targets: ["LanaPurchases"])
    ],
    dependencies: [
        .package(path: "../LanaCore")
    ],
    targets: [
        .target(
            name: "LanaPurchases",
            dependencies: ["LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "LanaPurchasesTests",
            dependencies: ["LanaPurchases", "LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
