// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "testcontainers-swift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "Testcontainers", targets: ["Testcontainers"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.94.1"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.31.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "DockerClientSwift",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            path: "Sources/DockerClientSwift"
        ),
        .target(
            name: "Testcontainers",
            dependencies: [
                "DockerClientSwift",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/Testcontainers"
        ),
        .testTarget(
            name: "TestcontainersTests",
            dependencies: ["Testcontainers"],
            path: "Tests"
        ),
    ]
)
