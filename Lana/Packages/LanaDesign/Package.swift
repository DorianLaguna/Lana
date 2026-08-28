// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LanaDesign",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LanaDesign", targets: ["LanaDesign"])
    ],
    targets: [
        .target(name: "LanaDesign", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "LanaDesignTests",
            dependencies: ["LanaDesign"],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
