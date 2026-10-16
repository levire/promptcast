// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PromptCast",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "PromptCastCore"),
        .executableTarget(name: "PromptCast", dependencies: ["PromptCastCore"], exclude: ["AGENTS.md"]),
        .testTarget(name: "PromptCastCoreTests", dependencies: ["PromptCastCore"]),
    ]
)
