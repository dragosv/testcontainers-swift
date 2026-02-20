# Testcontainers for Swift modules

In this section you'll find documentation for the pre-configured container modules available in Testcontainers for Swift. Each module provides sensible defaults for a specific technology — image, ports, environment variables, and wait strategies — so you can get started with minimal configuration.

## Available modules

| Module                              | Default Image   | Default Port | Connection Method       |
|-------------------------------------|-----------------|:------------:|-------------------------|
| [PostgreSQL](postgres.md)           | `postgres:latest` | 5432       | `getConnectionString()` |
| [MySQL](mysql.md)                   | `mysql:latest`    | 3306       | `getConnectionString()` |
| [Redis](redis.md)                   | `redis:latest`    | 6379       | `getRedisURL()`         |
| [MongoDB](mongodb.md)               | `mongo:latest`    | 27017      | `getConnectionString()` |

## Usage pattern

All modules follow a **two-phase builder → reference** pattern:

1. **Configure** using the builder (e.g., `PostgresContainer()`), calling fluent methods that return `Self`.
2. **Start** with `.start()`, which returns a reference object (e.g., `PostgresContainerReference`) exposing runtime helpers.

```swift
// 1. Configure
let ref = try await PostgresContainer()
    .withDatabase("testdb")
    .withUsername("admin")
    .withPassword("secret")
    // 2. Start — returns PostgresContainerReference
    .start()

// Use the reference
let connectionString = try ref.getConnectionString()

// Cleanup
try await ref.container.stop(timeout: 10)
```

## Image versions

Each module defaults to the `latest` tag. Pass a version string to the initializer to pin a specific version:

```swift
let ref = try await PostgresContainer(version: "16")
    .withDatabase("testdb")
    .start()
```

!!! tip

    Always pin image versions in CI to avoid flaky tests caused by image updates.

## Creating a new module

To add a new module, follow the existing pattern in `Sources/Testcontainers/Modules.swift`:

1. Create a builder class with sensible defaults (image, port, environment variables, wait strategy).
2. Add builder methods (e.g., `withDatabase(_:)`, `withUsername(_:)`) annotated with `@discardableResult`.
3. Create a reference class (e.g., `MyServiceContainerReference`) that wraps the running container and exposes convenience methods like `getConnectionString()`.
4. The `start()` method on the builder should configure the `ContainerBuilder`, create, start, and return the reference.

```swift
public class MyServiceContainer {
    private let builder: ContainerBuilder
    private var port: Int = 1234

    public init(version: String = "latest") {
        self.builder = ContainerBuilder("myservice:\(version)")
            .withPortBinding(1234, assignRandomHostPort: true)
    }

    @discardableResult
    public func withSomeSetting(_ value: String) -> MyServiceContainer {
        builder.withEnvironment("MY_SETTING", value)
        return self
    }

    public func start() async throws -> MyServiceContainerReference {
        let container = try await builder
            .withWaitStrategy(Wait.tcp(port: port))
            .buildAsync()
        try await container.start()
        return MyServiceContainerReference(container: container, port: port)
    }
}

public class MyServiceContainerReference: @unchecked Sendable {
    public let container: Container
    public let port: Int

    init(container: Container, port: Int) {
        self.container = container
        self.port = port
    }

    public func getConnectionString() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(port)
        return "myservice://\(host):\(mappedPort)"
    }
}
```

See [AGENTS.md](https://github.com/dragosv/testcontainers-swift/blob/main/AGENTS.md) for the full contribution guidelines for adding modules.
