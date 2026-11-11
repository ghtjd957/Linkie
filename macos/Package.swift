// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Linkie",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Linkie",
            path: "Sources/Linkie"
        ),
        .testTarget(
            name: "LinkieTests",
            dependencies: ["Linkie"],
            path: "Tests/LinkieTests",
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
