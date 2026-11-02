// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CaffeineWatch",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "CaffeineWatch", path: "Sources/CaffeineWatch")
    ]
)
