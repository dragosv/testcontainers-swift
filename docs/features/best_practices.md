# Best practices

This page provides guidelines for writing reliable, maintainable tests with Testcontainers for Swift.

## Use random host ports

Avoid binding fixed host ports. Use `assignRandomHostPort: true` to prevent port conflicts, especially in CI environments where tests may run in parallel.

```swift
// ✅ Good
let container = try await ContainerBuilder("postgres:16")
    .withPortBinding(5432, assignRandomHostPort: true)
    .buildAsync()

let port = try container.getMappedPort(5432)
```

```swift
// ❌ Avoid
let container = try await ContainerBuilder("postgres:16")
    .withPortBinding(hostPort: 5432, containerPort: 5432)
    .buildAsync()
```

## Pin image versions

Always use a specific image tag. Never rely on `latest`, which can change unexpectedly and break your tests.

```swift
// ✅ Good
ContainerBuilder("postgres:16.4")

// ❌ Avoid
ContainerBuilder("postgres:latest")
```

## Use wait strategies

Configure a wait strategy so your test only proceeds after the service is fully ready. Without one, tests may fail intermittently due to race conditions.

```swift
let container = try await ContainerBuilder("postgres:16")
    .withEnvironment("POSTGRES_PASSWORD", "password")
    .withPortBinding(5432, assignRandomHostPort: true)
    .withWaitStrategy(
        Wait.all(
            Wait.tcp(port: 5432),
            Wait.log(message: "database system is ready to accept connections")
        )
    )
    .buildAsync()
```

See [Wait Strategies](wait/introduction.md) for all available strategies.

## Use pre-configured modules

When a pre-configured module exists (PostgreSQL, MySQL, Redis, MongoDB), prefer it over raw `ContainerBuilder`. Modules provide sensible defaults, correct wait strategies, and convenience methods like `getConnectionString()`.

```swift
// ✅ Good — uses the pre-configured module
let ref = try await PostgresContainer()
    .withDatabase("testdb")
    .withUsername("admin")
    .withPassword("secret")
    .start()

let connectionString = try ref.getConnectionString()
```

See [Modules](../modules/index.md) for all available modules.

## Clean up containers

Always clean up containers when tests complete. Use `defer` or XCTest's `tearDown()`:

```swift
// Using defer
func testSomething() async throws {
    let container = try await ContainerBuilder("postgres:16")
        .withEnvironment("POSTGRES_PASSWORD", "password")
        .withPortBinding(5432, assignRandomHostPort: true)
        .buildAsync()
    try await container.start()
    defer { Task { try? await container.stop(timeout: 10) } }

    // test logic...
}
```

See [Garbage Collector](garbage_collector.md) for detailed cleanup patterns.

## Avoid detached tasks for cleanup

Prefer structured concurrency and `defer` over detached tasks. Detached tasks can complete after the test finishes, leading to unreliable cleanup.

```swift
// ✅ Good
defer { Task { try? await container.stop(timeout: 10) } }

// ❌ Avoid
Task.detached { try? await container.stop(timeout: 10) }
```

## Use network aliases for inter-container communication

When containers need to communicate, use custom networks with aliases instead of `localhost`:

```swift
let network = try await NetworkBuilder("test-net").build()

let db = try await ContainerBuilder("postgres:16")
    .withNetwork(network)
    .withNetworkAliases(["db"])
    .buildAsync()
```

See [Networking](networking.md) for detailed networking patterns.

## Start containers in parallel

When you need multiple containers, use `async let` to start them concurrently:

```swift
async let pgStart = PostgresContainer()
    .withDatabase("testdb")
    .start()

async let redisStart = RedisContainer().start()

let pgRef = try await pgStart
let redisRef = try await redisStart
```

## Configure logging for debugging

Use `swift-log` to diagnose container issues:

```swift
import Logging

var logger = Logger(label: "testcontainers")
logger.logLevel = .debug
```
