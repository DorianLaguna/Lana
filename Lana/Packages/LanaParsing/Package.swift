// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LanaParsing",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LanaParsing", targets: ["LanaParsing"])
    ],
    dependencies: [
        .package(path: "../LanaCore")
    ],
    targets: [
        .target(
            name: "LanaParsing",
            dependencies: ["LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .executableTarget(
            name: "parser-eval",
            dependencies: ["LanaParsing", "LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "LanaParsingTests",
            dependencies: ["LanaParsing", "LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
