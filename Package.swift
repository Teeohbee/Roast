// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Roast",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "RoastKit",
            path: "Sources/RoastKit"
        ),
        .executableTarget(
            name: "Roast",
            dependencies: ["RoastKit"],
            path: "Sources/Roast"
        ),
        .executableTarget(
            name: "RoastTests",
            dependencies: ["RoastKit"],
            path: "Tests/RoastTests"
        ),
    ]
)
