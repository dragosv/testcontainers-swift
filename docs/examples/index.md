# Examples

This page demonstrates common usage patterns for Testcontainers for Swift, from basic container management through to multi-container setups.

## Basic HTTP container

Start an NGINX container, wait for it to be ready, and make an HTTP request:

```swift
import Testcontainers
import Foundation

let container = try await ContainerBuilder("nginx:1.26-alpine")
    .withPortBinding(80, assignRandomHostPort: true)
    .withWaitStrategy(Wait.http(port: 80))
    .buildAsync()

try await container.start()
defer { Task { try? await container.stop(timeout: 10) } }

let host = container.host ?? "localhost"
let port = try container.getMappedPort(80)

let url = URL(string: "http://\(host):\(port)")!
let (_, response) = try await URLSession.shared.data(from: url)
let httpResponse = response as! HTTPURLResponse
print("Status: \(httpResponse.statusCode)") // 200
```

## Database module

Use the pre-configured [PostgreSQL module](../modules/postgres.md) for zero-config database testing:

```swift
import Testcontainers

let ref = try await PostgresContainer()
    .withDatabase("myapp_test")
    .withUsername("admin")
    .withPassword("secret")
    .start()

defer { Task { try? await ref.stop() } }

let connectionString = try ref.getConnectionString()
// "postgresql://admin:secret@localhost:55432/myapp_test"
```

## Combined wait strategies

Wait for multiple conditions before considering a container ready:

```swift
import Testcontainers

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

try await container.start()
defer { Task { try? await container.stop(timeout: 10) } }

// Container is guaranteed to have port 5432 listening
// AND the log message present
```

## Multi-container network

Connect multiple containers through a custom Docker network:

```swift
import Testcontainers

// Create a shared network
let network = try await NetworkBuilder("app-network").build()

// Start services
let pgRef = try await PostgresContainer()
    .withDatabase("mydb")
    .withUsername("admin")
    .withPassword("secret")
    .start()

let redisRef = try await RedisContainer().start()

// Connect both to the network
try await network.connectContainer(id: pgRef.container.id!)
try await network.connectContainer(id: redisRef.container.id!)

defer {
    Task {
        try? await pgRef.stop()
        try? await redisRef.stop()
    }
}

print("PostgreSQL: \(try pgRef.getConnectionString())")
print("Redis: \(try redisRef.getRedisURL())")
```

## Parallel container startup

Start multiple containers concurrently with `async let`:

```swift
import Testcontainers

async let pgStart = PostgresContainer()
    .withDatabase("testdb")
    .withUsername("admin")
    .withPassword("secret")
    .start()

async let redisStart = RedisContainer().start()

let pgRef = try await pgStart
let redisRef = try await redisStart

defer {
    Task {
        try? await pgRef.stop()
        try? await redisRef.stop()
    }
}

print("PostgreSQL: \(try pgRef.getConnectionString())")
print("Redis: \(try redisRef.getRedisURL())")
```

## Executing commands in a container

Run commands inside a running container:

```swift
import Testcontainers

let container = try await ContainerBuilder("alpine:latest")
    .withCmd(["sleep", "30"])
    .buildAsync()

try await container.start()
defer { Task { try? await container.stop(timeout: 10) } }

let output = try await container.exec(command: ["echo", "Hello from Alpine"])
print(output) // "Hello from Alpine"
```

## Reading container logs

Access stdout/stderr from a running container:

```swift
import Testcontainers

let container = try await ContainerBuilder("alpine:latest")
    .withCmd(["sh", "-c", "echo 'Application started' && sleep 30"])
    .buildAsync()

try await container.start()
defer { Task { try? await container.stop(timeout: 10) } }

try await Task.sleep(nanoseconds: 2_000_000_000)
let logs = try await container.getLogs()
print(logs) // "Application started\n"
```

## XCTest integration

See the [XCTest Integration](../test_frameworks/xctest.md) page for complete testing patterns, including `setUp`/`tearDown`, shared containers, and parallel test support.

```swift
import XCTest
import Testcontainers

final class IntegrationTests: XCTestCase {
    var postgresRef: PostgresContainerReference?

    override func setUp() async throws {
        postgresRef = try await PostgresContainer()
            .withDatabase("testdb")
            .withUsername("admin")
            .withPassword("secret")
            .start()
    }

    override func tearDown() async throws {
        try? await postgresRef?.stop()
    }

    func testDatabaseReachable() async throws {
        let conn = try postgresRef!.getConnectionString()
        XCTAssertTrue(conn.contains("testdb"))
    }
}
```
