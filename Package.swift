// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScreenInk",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "ScreenInkCore"),
        .executableTarget(name: "ScreenInk", dependencies: ["ScreenInkCore"], exclude: ["AGENTS.md"]),
        .testTarget(name: "ScreenInkCoreTests", dependencies: ["ScreenInkCore"]),
    ]
)
