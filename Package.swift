// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClockworkClaude",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClockworkClaude",
            path: "Sources/ClockworkClaude"
        )
    ]
)
