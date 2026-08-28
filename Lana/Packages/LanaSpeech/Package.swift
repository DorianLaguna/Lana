// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LanaSpeech",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LanaSpeech", targets: ["LanaSpeech"])
    ],
    dependencies: [
        .package(path: "../LanaCore")
    ],
    targets: [
        .target(
            name: "LanaSpeech",
            dependencies: ["LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "LanaSpeechTests",
            dependencies: ["LanaSpeech", "LanaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
