# Testcontainers Swift — Architecture

This document describes the internal design and architectural decisions of the library.
For a feature inventory and implementation stats see [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md).
For usage examples and getting-started instructions see [QUICKSTART.md](QUICKSTART.md).

## Design Goals

| Goal | Approach |
|------|----------|
| Swift-first | Protocols, value types, async/await, `Sendable` |
| Type safety | Swift's type system enforces container configuration correctness |
| Developer experience | Fluent builder API, DSL-style wait strategies |
| Minimal coupling | Two clearly separated modules with a defined boundary |
| Testability | All I/O hidden behind protocols; containers are easy to mock |

## Module Boundary

The library is split into two Swift Package targets with a strict dependency direction:

```
Testcontainers  ──depends on──►  DockerClientSwift  ──speaks to──►  Docker Engine
(high-level API)                  (low-level HTTP)                   (REST API)
```

**DockerClientSwift** is a self-contained Docker API client. It knows nothing about test containers, wait strategies, or modules. It translates Swift function calls into Docker Engine REST requests over a Unix socket or TCP.

**Testcontainers** owns all concepts meaningful to test authors: container lifecycle, wait strategies, pre-configured modules, and network management. It delegates all Docker I/O to `DockerClientSwift`.

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  Testcontainers module                                          │
│                                                                 │
│  ┌─────────────┐   builds   ┌──────────────────────────────┐  │
│  │  Modules    │──────────► │  ContainerBuilder             │  │
│  │  (Postgres, │            │  (fluent config, port binding,│  │
│  │   MySQL,    │            │   env vars, wait strategy)    │  │
│  │   Redis,    │            └──────────────┬───────────────┘  │
│  │   Mongo)    │                           │ builds            │
│  └─────────────┘                           ▼                   │
│                              ┌─────────────────────────┐       │
│                              │  DockerContainerImpl     │       │
│                              │  (implements Container   │       │
│                              │   protocol)              │       │
│                              └──────────┬──────────────┘       │
│                                         │ uses                  │
│  ┌──────────────────┐                   │                       │
│  │  WaitStrategy    │◄──────────────────┤                       │
│  │  (protocol +     │                   │                       │
│  │   7 impls)       │                   │                       │
│  └──────────────────┘                   │                       │
│                                         │                       │
│  ┌──────────────────┐                   │                       │
│  │  Network         │◄──────────────────┘                       │
│  │  (DockerNetwork  │                                           │
│  │   + Builder)     │                                           │
│  └──────────────────┘                                           │
│                    │ delegates all Docker I/O                   │
└────────────────────┼────────────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  DockerClientSwift module                                       │
│                                                                 │
│  DockerClient  ──►  Container API  ──►  Unix socket / TCP       │
│               ──►  Image API                                    │
│               ──►  Network API                                  │
│               ──►  System API                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Design Patterns

### 1. Protocol-Oriented Core

Every major abstraction is a protocol, not a base class:

```swift
public protocol Container: AnyObject {
    var id: String { get }
    func start() async throws
    func stop(timeout: Int) async throws
    func getMappedPort(_ containerPort: Int) throws -> Int
    // ...
}

public protocol WaitStrategy {
    func waitUntilReady(container: any Container, client: DockerClient) async throws
}
```

This makes individual components independently testable and replaceable without inheritance hierarchies.

### 2. Builder Pattern with Method Chaining

`ContainerBuilder` accumulates configuration and executes it only when `build()` / `buildAsync()` is called. Each configuration method returns `Self`, enabling chaining:

```swift
ContainerBuilder("postgres:15")
    .withPortBinding(5432, assignRandomHostPort: true)
    .withEnvironment(["POSTGRES_DB": "test"])
    .withWaitStrategy(Wait.tcp(port: 5432))
    .build()
```

Modules extend this by pre-populating the builder with sensible defaults and then exposing domain-specific methods (`withDatabase`, `withUsername`, etc.).

### 3. Strategy Pattern for Readiness

`WaitStrategy` implementations are composable and interchangeable. The `Wait` class acts as a DSL factory:

| Strategy | Mechanism |
|----------|-----------|
| `NoWaitStrategy` | Returns immediately |
| `HttpWaitStrategy` | Polls HTTP endpoint for 2xx |
| `TcpWaitStrategy` | Opens TCP connection |
| `LogWaitStrategy` | Scans container log stream |
| `ExecWaitStrategy` | Runs a command inside the container |
| `HealthCheckWaitStrategy` | Reads Docker health-check status |
| `CombinedWaitStrategy` | Executes a list of strategies sequentially |

Strategies are polled with configurable timeout and backoff — the `Container` is passed in so strategies can call `exec()` or `getLogs()` without coupling to a specific implementation.

### 4. Reference Types for Lifecycle Management

`DockerContainerImpl` and `DockerNetworkImpl` are classes, not structs. This is intentional:

- A container is a live external resource — shared references to the same object are desirable.
- Lifecycle methods mutate internal state (container ID, mapped ports).
- `@unchecked Sendable` is used on the Docker client because the underlying HTTP session is thread-safe by design.

### 5. Module Pattern

Each pre-configured module consists of two types:

```
PostgresContainer          — builder, configures defaults, exposes withDatabase() etc.
    └─ .start() ──────────► PostgresContainerReference  — running container + getConnectionString()
```

This keeps the configuration phase separate from the runtime phase and prevents calling `getConnectionString()` before the container has started.

## Concurrency Model

All I/O operations are `async throws`. The library targets Swift Concurrency (async/await) exclusively — there are no callbacks or Combine publishers.

**Thread safety** is handled at two levels:
- `DockerClientSwift` uses `AsyncHTTPClient` (backed by SwiftNIO) whose `EventLoop` manages I/O concurrency.
- The `TestcontainersDockerClient` wrapper is `@unchecked Sendable` because the underlying HTTP client is safe to share across tasks.

Callers are responsible for ensuring that container references are not accessed from multiple tasks simultaneously unless those accesses are read-only.

## Docker Endpoint Detection

The client attempts endpoints in this order:

1. `/var/run/docker.sock` — standard Unix socket
2. `~/.docker/run/docker.sock` — Docker Desktop on macOS
3. `DOCKER_HOST` environment variable
4. `tcp://localhost:2375` — TCP fallback

Once a reachable endpoint is found it is cached for the lifetime of the client.

## Error Model

`TestcontainersError` is a typed enum so callers can pattern-match specific failure modes:

```swift
public enum TestcontainersError: Error {
    case dockerNotAvailable
    case containerNotFound(id: String)
    case waitStrategyFailed(reason: String)
    case portMappingFailed(port: Int)
    case timeout
    case apiError(message: String)
    case invalidConfiguration(reason: String)
}
```

## Port Mapping

When `assignRandomHostPort: true` is set the Docker Engine allocates a free host port. The mapping is captured after container start by calling the `/containers/{id}/json` inspect endpoint and stored in the container object. `getMappedPort(_:)` reads this local cache — it does not make a network call.

Internally ports are keyed as `"\(port)/tcp"` to match the Docker API format.

## Network Isolation

Bridge networks are the recommended approach for inter-container communication in tests:

- Each container gets a DNS name equal to its network alias.
- Containers on the same bridge network can reach each other by alias without exposing ports to the host.
- `NetworkBuilder` creates an isolated bridge and `DockerNetworkImpl` manages its lifetime.

## References

- [Docker Engine API v1.44](https://docs.docker.com/engine/api/v1.44/)
- [Swift Concurrency — async/await proposal](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md)
- [testcontainers-dotnet](https://github.com/testcontainers/testcontainers-dotnet) — reference architecture
- [docker-client-swift](https://github.com/alexsteinerde/docker-client-swift) — origin of DockerClientSwift module
