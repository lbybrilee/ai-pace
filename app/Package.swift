// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AIPace",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "AIPace",
            path: "Sources/AIPace"
        ),
    ]
)
