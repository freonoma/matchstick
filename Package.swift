// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Matchstick",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Matchstick")
    ]
)
