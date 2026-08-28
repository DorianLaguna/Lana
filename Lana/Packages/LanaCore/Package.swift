// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LanaCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LanaCore", targets: ["LanaCore"])
    ],
    targets: [
        .target(name: "LanaCore", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "LanaCoreTests",
            dependencies: ["LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
