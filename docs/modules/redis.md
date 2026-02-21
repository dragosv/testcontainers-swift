# Redis

## Introduction

The Testcontainers module for Redis provides a pre-configured container for running a Redis instance in your tests. It uses the official [`redis`](https://hub.docker.com/_/redis) Docker image.

Redis is the simplest module — it requires no credentials or database configuration by default.

## Adding the dependency

Add Testcontainers to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dragosv/testcontainers-swift.git", from: "0.1.0"),
],
targets: [
    .testTarget(
        name: "MyAppTests",
        dependencies: [
            .product(name: "Testcontainers", package: "testcontainers-swift"),
        ]
    ),
]
```

## Usage example

<!--codeinclude-->

```swift
import Testcontainers
import XCTest

final class RedisTests: XCTestCase {
    func testRedisConnection() async throws {
        let ref = try await RedisContainer().start()

        defer {
            Task { try? await ref.stop() }
        }

        let redisURL = try ref.getRedisURL()
        // redisURL: "redis://localhost:XXXXX"

        // Use redisURL with your Redis client
    }
}
```

<!--/codeinclude-->

## Module Reference

### `RedisContainer`

The `RedisContainer` class configures and starts a Redis instance.

#### Initializer

```swift
public init(version: String = "latest")
```

Creates a new Redis container with the given version tag. The container is pre-configured with:

- **Image**: `redis:<version>`
- **Port**: `6379` (mapped to a random host port)

#### Container Options

The Redis module does not expose additional configuration methods. To customise the container further, use the underlying `ContainerBuilder` directly (see [Creating a Container](../features/creating_container.md)).

#### Wait Strategy

The module uses a single wait strategy (applied automatically):

| Strategy | Configuration |
|----------|---------------|
| HTTP     | Port `6379` with 60 s timeout |

#### Start

```swift
public func start() async throws -> RedisContainerReference
```

Builds the container, starts it, and returns a `RedisContainerReference`.

### `RedisContainerReference`

The reference object returned after the container starts.

#### Properties

| Property    | Type        | Description                       |
|-------------|-------------|-----------------------------------|
| `container` | `Container` | The underlying container instance |
| `port`      | `Int`       | The internal port (`6379`)        |

#### Container Methods

| Method          | Return Type | Description                         |
|-----------------|-------------|-------------------------------------|
| `getRedisURL()` | `String`    | Returns a `redis://` connection URI |
| `stop()`        | `Void`      | Stops the container (10 s timeout)  |
| `delete()`      | `Void`      | Removes the container               |

##### Connection URL format

```
redis://<host>:<mapped-port>
```

## Examples

### Default configuration

```swift
let ref = try await RedisContainer().start()
let url = try ref.getRedisURL()
// "redis://localhost:XXXXX"
```

### Pinned version

```swift
let ref = try await RedisContainer(version: "7").start()
let url = try ref.getRedisURL()
```

### Using with defer cleanup

```swift
func testCaching() async throws {
    let ref = try await RedisContainer().start()
    defer { Task { try? await ref.stop() } }

    let url = try ref.getRedisURL()
    // Connect your Redis client to url
}
```
