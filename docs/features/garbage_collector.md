# Garbage Collector

Typically, an integration test creates one or more containers. This can mean a lot of containers running by the time everything is done. We need to have a way to clean up after ourselves to keep our machines running smoothly.

Containers can be unused because:

1. The test is over and the container is not needed anymore.
2. The test failed, and we do not need that container anymore because the next build will create new ones.

## Cleanup patterns

### Using `defer`

The most common pattern for cleaning up containers is `defer` with a `Task`:

```swift
let container = try await ContainerBuilder("postgres:16")
    .withEnvironment("POSTGRES_PASSWORD", "password")
    .withPortBinding(5432, assignRandomHostPort: true)
    .buildAsync()

try await container.start()
defer { Task { try? await container.stop(timeout: 10) } }

// Test logic...
```

!!! tip

    Use `try?` when stopping containers in cleanup code to avoid masking the original test failure with a cleanup error.

### Using XCTest lifecycle

Use `setUp()` and `tearDown()` in XCTest to manage container lifecycle:

```swift
class DatabaseTests: XCTestCase {
    var container: Container?

    override func setUp() async throws {
        container = try await ContainerBuilder("postgres:16")
            .withEnvironment("POSTGRES_PASSWORD", "password")
            .withPortBinding(5432, assignRandomHostPort: true)
            .withWaitStrategy(Wait.log(message: "database system is ready"))
            .buildAsync()
        try await container!.start()
    }

    override func tearDown() async throws {
        try? await container?.stop(timeout: 10)
    }

    func testQuery() async throws {
        // container is available and started
    }
}
```

### Using labels for CI cleanup

You can label containers and clean them up in CI scripts as a safety net:

```swift
let container = try await ContainerBuilder("postgres:16")
    .withLabel("testcontainers", "true")
    .withLabel("testcontainers.session", UUID().uuidString)
    .buildAsync()
```

Then in your CI pipeline:

```bash
# Clean up any leftover test containers
docker rm -f $(docker ps -aq --filter "label=testcontainers=true") 2>/dev/null || true
```

## Resource Reaper (Ryuk)

!!! note "Not yet implemented"

    Automatic resource reaping (Ryuk) is not yet available in Testcontainers for Swift. This feature is planned for a future release.

In other Testcontainers implementations, a "resource reaper" called [Ryuk](https://github.com/testcontainers/moby-ryuk) runs as a sidecar container that automatically cleans up containers, networks, and volumes created during tests — even if the test process crashes or is killed.

When available, you will see an additional container called `ryuk` alongside all the containers that were specified in your test. It relies on container labels to determine which resources were created by the package to determine the entities that are safe to remove.

Until the resource reaper is implemented, ensure you clean up resources using one of the manual patterns described above.

!!! tip

    In CI environments, consider adding a post-build step to clean up any Docker containers with the `testcontainers` label as a safety net.
