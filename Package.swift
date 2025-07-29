// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "AgentSignal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AgentSignal",
            targets: ["AgentSignal"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AgentSignal",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "AgentSignalTests",
            dependencies: ["AgentSignal"]
        )
    ]
)