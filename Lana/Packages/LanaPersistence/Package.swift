// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LanaPersistence",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LanaPersistence", targets: ["LanaPersistence"])
    ],
    dependencies: [
        .package(path: "../LanaCore")
    ],
    targets: [
        .target(
            name: "LanaPersistence",
            dependencies: ["LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "LanaPersistenceTests",
            dependencies: ["LanaPersistence", "LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
