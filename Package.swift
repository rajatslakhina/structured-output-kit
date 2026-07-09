// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "StructuredOutputKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "StructuredOutputKit", targets: ["StructuredOutputKit"]),
        .executable(name: "StructuredOutputDemo", targets: ["StructuredOutputKitDemo"])
    ],
    targets: [
        .target(
            name: "StructuredOutputKit"
        ),
        .executableTarget(
            name: "StructuredOutputKitDemo",
            dependencies: ["StructuredOutputKit"]
        ),
        .testTarget(
            name: "StructuredOutputKitTests",
            dependencies: ["StructuredOutputKit"]
        )
    ]
)
