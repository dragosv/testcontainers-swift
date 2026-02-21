# XCTest Integration

Testcontainers for Swift integrates with Apple's [XCTest](https://developer.apple.com/documentation/xctest) framework. This page covers recommended patterns for managing container lifecycles in your tests.

## Per-test container with `defer`

The simplest pattern — start a container at the beginning of a test and clean up with `defer`:

```swift
import XCTest
import Testcontainers

final class SimpleTests: XCTestCase {
    func testRedis() async throws {
        let ref = try await RedisContainer().start()
        defer { Task { try? await ref.stop() } }

        let redisURL = try ref.getRedisURL()
        XCTAssertTrue(redisURL.hasPrefix("redis://"))
    }
}
```

This is ideal when a test needs its own isolated container.

## Per-test container with `setUp` / `tearDown`

Use `setUp()` and `tearDown()` when every test method in a class needs the same container type:

```swift
import XCTest
import Testcontainers

final class DatabaseTests: XCTestCase {
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

    func testInsert() async throws {
        let conn = try postgresRef!.getConnectionString()
        XCTAssertTrue(conn.hasPrefix("postgresql://"))
    }

    func testSelect() async throws {
        let conn = try postgresRef!.getConnectionString()
        XCTAssertTrue(conn.contains("testdb"))
    }
}
```

Each test method gets a fresh container, ensuring complete isolation.

## Shared container across a test class

To avoid the overhead of starting a new container for every test method, share one container at the class level:

```swift
import XCTest
import Testcontainers

final class SharedContainerTests: XCTestCase {
    static var postgresRef: PostgresContainerReference?

    override func setUp() async throws {
        if Self.postgresRef == nil {
            Self.postgresRef = try await PostgresContainer()
                .withDatabase("testdb")
                .withUsername("admin")
                .withPassword("secret")
                .start()
        }
    }

    override class func tearDown() {
        Task { try? await postgresRef?.stop() }
        super.tearDown()
    }

    func testInsert() async throws {
        let conn = try Self.postgresRef!.getConnectionString()
        // Use shared container...
    }

    func testSelect() async throws {
        let conn = try Self.postgresRef!.getConnectionString()
        // Use shared container...
    }
}
```

!!! warning

    When sharing containers, ensure tests don't leave state that interferes with other test methods. Consider resetting data between tests or using separate databases.

## Generic container test

Use `ContainerBuilder` directly for images that don't have a pre-configured [module](../modules/index.md):

```swift
func testCustomContainer() async throws {
    let container = try await ContainerBuilder("httpbin/httpbin:latest")
        .withPortBinding(80, assignRandomHostPort: true)
        .withWaitStrategy(Wait.http(port: 80, path: "/uuid"))
        .buildAsync()

    try await container.start()
    defer { Task { try? await container.stop(timeout: 10) } }

    let host = container.host ?? "localhost"
    let port = try container.getMappedPort(80)

    let url = URL(string: "http://\(host):\(port)/uuid")!
    let (data, response) = try await URLSession.shared.data(from: url)
    let httpResponse = response as! HTTPURLResponse
    XCTAssertEqual(httpResponse.statusCode, 200)
}
```

## Parallel container startup

Start multiple containers concurrently using `async let`:

```swift
func testMultipleServices() async throws {
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

    XCTAssertTrue(try pgRef.getConnectionString().hasPrefix("postgresql://"))
    XCTAssertTrue(try redisRef.getRedisURL().hasPrefix("redis://"))
}
```

## Executing commands

Run commands inside a container and assert on the output:

```swift
func testExec() async throws {
    let container = try await ContainerBuilder("alpine:latest")
        .withCmd(["sleep", "30"])
        .buildAsync()

    try await container.start()
    defer { Task { try? await container.stop(timeout: 10) } }

    let output = try await container.exec(command: ["echo", "Hello from Alpine"])
    XCTAssertTrue(output.contains("Hello from Alpine"))
}
```

## Checking container logs

Assert on log output from a container:

```swift
func testLogs() async throws {
    let container = try await ContainerBuilder("alpine:latest")
        .withCmd(["sh", "-c", "echo 'Test output' && sleep 30"])
        .buildAsync()

    try await container.start()
    defer { Task { try? await container.stop(timeout: 10) } }

    try await Task.sleep(nanoseconds: 2_000_000_000)
    let logs = try await container.getLogs()
    XCTAssertTrue(logs.contains("Test output"))
}
```

## Best practices

| Practice | Recommendation |
|----------|---------------|
| **Cleanup** | Always use `defer` or `tearDown` to stop containers |
| **Isolation** | Prefer per-test containers unless startup cost is prohibitive |
| **Timeouts** | Set generous test timeouts — container pulls can be slow |
| **Port binding** | Always use random host ports (`assignRandomHostPort: true`) |
| **Wait strategies** | Always specify a wait strategy to avoid race conditions |
| **Parallel starts** | Use `async let` to start independent containers concurrently |

See [Best Practices](../features/best_practices.md) for more recommendations.
