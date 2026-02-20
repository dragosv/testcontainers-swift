# Wait strategies — Introduction

Wait strategies detect when a container is ready for testing. They check different indicators of readiness and complete as soon as they are fulfilled. By default, Testcontainers will proceed without waiting. For most images, you should configure a wait strategy to ensure the service is fully ready before running tests.

## Available strategies

| Strategy                                  | Description                                                           |
|-------------------------------------------|-----------------------------------------------------------------------|
| [HTTP](#wait-for-http)                    | Waits for an HTTP endpoint to return a 2xx status code.               |
| [TCP](#wait-for-tcp)                      | Waits for a TCP port to be reachable.                                 |
| [Log](#wait-for-log)                      | Waits for a specific message in the container logs.                   |
| [Exec](#wait-for-exec)                    | Waits for a command to succeed inside the container.                  |
| [Health check](#wait-for-health-check)    | Waits for Docker's HEALTHCHECK to report healthy.                     |
| [Combined](#combining-strategies)         | Waits for multiple strategies to all succeed.                         |
| [Custom](#custom-wait-strategy)           | Custom logic via closure or protocol conformance.                     |
| [No wait](#no-wait)                       | Proceeds immediately without waiting.                                 |

## Startup timeout

Each wait strategy supports a configurable timeout. The default timeout is **60 seconds**. If the strategy does not succeed within the timeout, a `TestcontainersError.timeout` or `TestcontainersError.waitStrategyFailed` error is thrown.

```swift
// Wait up to 2 minutes
Wait.log(message: "Server started", timeout: 120)
```

## Setting a wait strategy

Set the wait strategy on the `ContainerBuilder`:

```swift
let container = try await ContainerBuilder("postgres:16")
    .withPortBinding(5432, assignRandomHostPort: true)
    .withEnvironment("POSTGRES_PASSWORD", "password")
    .withWaitStrategy(
        Wait.all(
            Wait.tcp(port: 5432),
            Wait.log(message: "database system is ready to accept connections")
        )
    )
    .buildAsync()
```

## Wait for HTTP

The HTTP wait strategy checks if an HTTP endpoint returns a successful response (status code 2xx). You can configure the port, path, scheme, and timeout.

```swift
// Basic — wait for port 8080 to respond with 2xx on "/"
Wait.http(port: 8080)

// Custom path and scheme
Wait.http(port: 443, path: "/health", scheme: "https", timeout: 120)
```

**Parameters:**

| Parameter  | Default | Description                          |
|------------|---------|--------------------------------------|
| `port`     | —       | The container port to check.         |
| `path`     | `"/"`   | The HTTP path to request.            |
| `scheme`   | `"http"`| The URL scheme (`http` or `https`).  |
| `timeout`  | `60`    | Maximum seconds to wait.             |

**Example:**

```swift
let container = try await ContainerBuilder("httpbin/httpbin:latest")
    .withPortBinding(80, assignRandomHostPort: true)
    .withWaitStrategy(Wait.http(port: 80, path: "/uuid"))
    .buildAsync()

try await container.start()
```

## Wait for TCP

The TCP wait strategy checks if a TCP port is reachable on the container. This verifies that a service is listening on the specified port.

```swift
Wait.tcp(port: 5432)
Wait.tcp(port: 5432, timeout: 120)
```

**Parameters:**

| Parameter  | Default | Description                          |
|------------|---------|--------------------------------------|
| `port`     | —       | The container port to check.         |
| `timeout`  | `60`    | Maximum seconds to wait.             |

!!! note

    Just because a service is listening on a TCP port does not necessarily mean it is fully ready to handle requests. Log-based or HTTP-based strategies often provide more reliable readiness confirmation.

## Wait for log

The log wait strategy monitors the container's stdout/stderr and completes when a specific message appears.

```swift
Wait.log(message: "database system is ready to accept connections")
Wait.log(message: "Ready to accept connections", timeout: 120)
```

**Parameters:**

| Parameter  | Default | Description                            |
|------------|---------|----------------------------------------|
| `message`  | —       | The substring to search for in logs.   |
| `timeout`  | `60`    | Maximum seconds to wait.               |

## Wait for exec

The exec wait strategy runs a command inside the container and waits until it succeeds (produces output).

```swift
Wait.exec(command: ["pg_isready", "-U", "postgres"])
Wait.exec(command: ["curl", "-f", "http://localhost:8080/health"], timeout: 90)
```

**Parameters:**

| Parameter  | Default | Description                               |
|------------|---------|-------------------------------------------|
| `command`  | —       | The command to execute as an array.       |
| `timeout`  | `60`    | Maximum seconds to wait.                  |

## Wait for health check

If the Docker image has a [HEALTHCHECK](https://docs.docker.com/engine/reference/builder/#healthcheck) instruction, you can wait for Docker to report the container as healthy:

```swift
Wait.healthCheck()
Wait.healthCheck(timeout: 120)
```

**Parameters:**

| Parameter  | Default | Description                          |
|------------|---------|--------------------------------------|
| `timeout`  | `60`    | Maximum seconds to wait.             |

## Combining strategies

Use `Wait.all(...)` to combine multiple wait strategies. All strategies must succeed for the container to be considered ready:

```swift
Wait.all(
    Wait.tcp(port: 5432),
    Wait.log(message: "database system is ready to accept connections")
)
```

Strategies are executed sequentially in the order provided.

## Custom wait strategy

### Protocol conformance

Implement the `WaitStrategy` protocol for custom readiness checks:

```swift
struct MyCustomWaitStrategy: WaitStrategy {
    func waitUntilReady(container: Container, client: DockerClient) async throws {
        var ready = false
        let startTime = Date()

        while !ready && Date().timeIntervalSince(startTime) < 60 {
            let output = try await container.exec(command: ["cat", "/tmp/ready"])
            ready = output.contains("OK")
            if !ready {
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        if !ready {
            throw TestcontainersError.waitStrategyFailed("Custom check failed")
        }
    }
}
```

### Closure-based

For simpler cases, use `CustomWaitStrategy` with a closure:

```swift
let strategy = CustomWaitStrategy { container, client in
    try await Task.sleep(nanoseconds: 5_000_000_000) // wait 5 seconds
}
```

## No wait

If you do not need to wait for the container to be ready (e.g., for fire-and-forget containers), use:

```swift
Wait.noWait()
```

## Summary

| Factory method          | Description                                                           |
|-------------------------|-----------------------------------------------------------------------|
| `Wait.noWait()`         | No waiting, proceeds immediately.                                     |
| `Wait.http(...)`        | Waits for an HTTP endpoint to return a 2xx status code.               |
| `Wait.tcp(...)`         | Waits for a TCP port to be reachable.                                 |
| `Wait.log(...)`         | Waits for a specific message in the container logs.                   |
| `Wait.exec(...)`        | Waits for a command to execute successfully inside the container.     |
| `Wait.healthCheck(...)` | Waits for Docker's built-in health check to report healthy.           |
| `Wait.all(...)`         | Combines multiple wait strategies; all must succeed.                  |
| `CustomWaitStrategy`    | Allows custom readiness logic via a closure.                          |
