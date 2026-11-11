// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tether",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tether",
            path: "Sources/Tether"
        ),
        .testTarget(
            name: "TetherTests",
            dependencies: ["Tether"],
            path: "Tests/TetherTests",
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
