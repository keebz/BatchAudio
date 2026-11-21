// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BatchAudio",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "BatchAudio", path: "Sources/BatchAudio")
    ]
)
