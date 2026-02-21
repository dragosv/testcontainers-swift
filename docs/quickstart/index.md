# Quickstart

Testcontainers for Swift integrates with Apple's XCTest framework and the native `swift test` command.

It is designed for integration and end-to-end tests, helping you spin up and manage the lifecycle of container-based dependencies via Docker.

## 1. System requirements

Please read the [System Requirements](../system_requirements/index.md) page before you start.

## 2. Install Testcontainers for Swift

We use Swift Package Manager. Add the dependency to your `Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MyProject",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/dragosv/testcontainers-swift.git", from: "0.1.0"),
    ],
    targets: [
        .testTarget(
            name: "MyProjectTests",
            dependencies: [
                .product(name: "Testcontainers", package: "testcontainers-swift"),
            ]
        ),
    ]
)
```

The package provides one public library product:

| Module              | Description                                                                                |
|---------------------|--------------------------------------------------------------------------------------------|
| `Testcontainers`    | High-level API with container builders, wait strategies, pre-configured modules, networks. |

The source tree also contains a `DockerClientSwift` target used internally by `Testcontainers`.

## 3. Spin up Redis

```swift
import XCTest
import Testcontainers

final class QuickstartTests: XCTestCase {
    func testWithRedis() async throws {
        let container = try await ContainerBuilder("redis:7")
            .withPortBinding(6379, assignRandomHostPort: true)
            .withWaitStrategy(
                Wait.log(message: "Ready to accept connections")
            )
            .buildAsync()

        try await container.start()
        defer { Task { try? await container.stop(timeout: 10) } }

        let host = container.host ?? "localhost"
        let port = try container.getMappedPort(6379)
        print("Redis available at \(host):\(port)")
    }
}
```

The `ContainerBuilder` receives the image name and is configured with a fluent API.

- `withPortBinding(_:assignRandomHostPort:)` exposes port 6379 from the container and maps it to a random available host port — just like `docker run -p 6379`.
- `withWaitStrategy(_:)` validates when a container is ready to receive traffic. In this case, we check for the log message that Redis emits when ready.

When you use `withPortBinding` with `assignRandomHostPort: true`, Docker maps the container port to a random available host port. This is crucial for parallelization — if you add multiple tests, each starts its own Redis container on a different random port.

`buildAsync()` pulls the image (if needed) and creates the container. We then call `start()` to begin executing.

All containers must be removed at some point, otherwise they will run until the host is overloaded. Using `defer` with `Task` ensures cleanup happens even if the test throws.

!!! tip

    Look at [Garbage Collector](../features/garbage_collector.md) to learn more about resource cleanup patterns.

## 4. Connect your code to the container

In a real project, you would pass this endpoint to your Redis client library. This snippet retrieves the endpoint from the container we just started:

```swift
let host = container.host ?? "localhost"
let port = try container.getMappedPort(6379)

// Use host:port with your Redis client library
// For example: "redis://\(host):\(port)"
```

We expose only one port, so the mapping is straightforward.

!!! tip

    If you expose more than one port, use `getMappedPort(_:)` with the specific container port you need.

## 5. Run the test

Run the test via:

```bash
swift test
```

## 6. Want to go deeper with Redis?

You can find a more complete Redis example using the pre-configured module in our [Redis module](../modules/redis.md) documentation.

Or use any of the other pre-configured [modules](../modules/index.md):

- [PostgreSQL](../modules/postgres.md)
- [MySQL](../modules/mysql.md)
- [Redis](../modules/redis.md)
- [MongoDB](../modules/mongodb.md)
