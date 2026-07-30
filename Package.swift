// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "CodexMeter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CodexMeter",
            path: "Sources/CodexMeter"
        )
    ]
)
