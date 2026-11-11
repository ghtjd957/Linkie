// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pluggy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pluggy",
            path: "Sources/Pluggy"
        ),
        .testTarget(
            name: "PluggyTests",
            dependencies: ["Pluggy"],
            path: "Tests/PluggyTests",
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
