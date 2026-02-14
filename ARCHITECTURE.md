# Testcontainers Swift - Architecture

This document describes the architecture and design of Testcontainers for Swift.

## Design Goals

1. **Swift-First**: Idiomatic Swift using protocols, value types, and modern concurrency
2. **Minimal Dependencies**: Use only Foundation for HTTP communication
3. **Type Safety**: Leverage Swift's type system for correctness
4. **Async/Await**: Built on Swift's async/await concurrency model
5. **Developer Experience**: Fluent API for easy container configuration
6. **Compatibility**: Support macOS, Linux, iOS, tvOS, and watchOS

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│          User Application Code              │
├─────────────────────────────────────────────┤
│  Module Layer (PostgreSQL, MySQL, etc.)    │
├─────────────────────────────────────────────┤
│  Container Builder & Management Layer       │
│  - ContainerBuilder: Fluent configuration   │
│  - Container: Protocol for lifecycle        │
│  - DockerContainerImpl: Docker implementation│
├─────────────────────────────────────────────┤
│  Docker Client & API Layer                 │
│  - DockerClient: REST API communication    │
│  - Models: Request/Response DTOs           │
├─────────────────────────────────────────────┤
│  Docker Engine (via Docker API)            │
└─────────────────────────────────────────────┘
```

## Core Components

### 1. Models (Models.swift)

Data structures representing Docker entities:

- **DockerContainer**: List container representation
- **ContainerInspect**: Detailed container information
- **ContainerState**: Runtime state information
- **PortBinding**: Port mapping configuration
- **DockerNetwork**: Network resource representation
- **CreateContainerRequest**: API request for container creation

**Design Pattern**: Codable structures for JSON serialization with Docker API

### 2. Docker Client (DockerClient.swift)

Low-level Docker API communication layer using Foundation's URLSession.

**Key Responsibilities**:
- HTTP communication with Docker daemon
- Endpoint auto-detection (Unix socket on macOS/Linux, TCP fallback)
- Request/response serialization and deserialization
- Container operations (create, start, stop, remove, inspect, exec, logs)
- Image operations (pull, inspect)
- Network operations (create, connect, disconnect)

**Architecture Pattern**: Actor-based for thread safety with static shared instance

**API Endpoints Used**:
- `/v1.44/containers/create` - Create container
- `/v1.44/containers/{id}/start` - Start container
- `/v1.44/containers/{id}/stop` - Stop container
- `/v1.44/containers/{id}/json` - Inspect container
- `/v1.44/containers/{id}/exec` - Execute command
- `/v1.44/containers/{id}/logs` - Get logs
- `/v1.44/images/create` - Pull image
- `/v1.44/networks/create` - Create network
- `/v1.44/networks/{id}/connect` - Connect to network

### 3. Wait Strategies (WaitStrategy.swift)

Implements the Strategy pattern for defining container readiness conditions.

**Core Protocol**:
```swift
public protocol WaitStrategy {
    func waitUntilReady(container: Container, client: DockerClient) async throws
}
```

**Implementations**:
- **NoWaitStrategy**: No waiting (immediate)
- **HttpWaitStrategy**: Wait for HTTP endpoint to return 2xx
- **TcpWaitStrategy**: Wait for TCP port to be available
- **LogWaitStrategy**: Wait for specific log message
- **ExecWaitStrategy**: Wait for command execution to succeed
- **HealthCheckWaitStrategy**: Wait for Docker health checks
- **CombinedWaitStrategy**: Execute multiple strategies sequentially

**Wait Builder API**: `Wait` class provides static methods for DSL-style configuration

```swift
Wait.http(port: 8080)
Wait.tcp(port: 3306)
Wait.all(.tcp(port: 5432), .http(port: 8080))
```

### 4. Container Protocol & Implementation (Container.swift)

Abstracts container lifecycle and operations.

**Container Protocol**:
```swift
public protocol Container: AnyObject {
    var id: String { get }
    var name: String? { get }
    var image: String { get }
    var host: String? { get }
    var ipAddress: String? { get }
    
    func start() async throws
    func stop(timeout: Int) async throws
    func delete() async throws
    func getMappedPort(_ containerPort: Int) throws -> Int
    func exec(command: [String]) async throws -> String
    func getLogs() async throws -> String
    func getState() async throws -> ContainerStatus
}
```

**Implementation**: `DockerContainerImpl` wraps Docker API calls and manages lifecycle

**Lifecycle Operations**:
1. Create (via Docker API)
2. Start (via Docker API)
3. Wait for readiness (via wait strategies)
4. Execute operations (exec, logs, etc.)
5. Stop (via Docker API)
6. Delete (via Docker API)

### 5. Container Builder (Container.swift)

Fluent API for container configuration.

**Pattern**: Builder pattern with method chaining returning `Self`

**Configuration Method Categories**:
- **Naming**: `withName()`
- **Environment**: `withEnvironment()`
- **Labels**: `withLabel()`
- **Ports**: `withPortBinding()`
- **Waiting**: `withWaitStrategy()`
- **Networking**: `withNetwork()`, `withNetworkAliases()`
- **Execution**: `withEntrypoint()`, `withCmd()`

**Build Phases**:
1. Configuration assembly (builder methods)
2. Image pull (if needed)
3. Container creation (Docker API)
4. Container start (Docker API)
5. Wait for readiness (configured strategy)

### 6. Network Management (Network.swift)

Docker network lifecycle and container connection management.

**DockerNetworkImpl**: Represents a Docker network with operations:
- `connectContainer()`: Add container to network
- `disconnectContainer()`: Remove container from network
- `delete()`: Remove network

**NetworkBuilder**: Fluent API for network creation
```swift
let network = try await NetworkBuilder("app-network")
    .withDriver("bridge")
    .build()
```

### 7. Modules (Modules.swift)

Pre-configured containers for common services.

**Module Pattern**:
1. **Container Class**: Configuration builder (e.g., `PostgresContainer`)
2. **Reference Class**: Started container with convenience methods (e.g., `PostgresContainerReference`)
3. **Defaults**: Environment variables, ports, wait strategies
4. **Extensions**: Service-specific methods like `getConnectionString()`

**Provided Modules**:
- **PostgreSQL**: Connection-ready Postgres database
- **MySQL**: Connection-ready MySQL database
- **Redis**: Connection-ready Redis instance
- **MongoDB**: Connection-ready MongoDB instance

## Concurrency Model

**Technology**: Swift async/await (async functions with `await` keywords)

**Benefits**:
- Structured concurrency eliminating callback hell
- Compiler-checked concurrency safety
- Seamless integration with modern Swift APIs

**Pattern**: All I/O operations are async
```swift
let container = try await builder.buildAsync()
try await container.start()
```

## Error Handling

**Error Type**: `TestcontainersError` enum with associated values

**Error Cases**:
- `.dockerNotAvailable` - Docker daemon not accessible
- `.containerNotFound(id)` - Container doesn't exist
- `.waitStrategyFailed(reason)` - Wait condition not met
- `.portMappingFailed(port)` - Port mapping error
- `.apiError(message)` - Docker API error
- `.timeout` - Operation exceeded timeout
- `.invalidConfiguration(reason)` - Invalid container config

**Error Handling Pattern**: Swift error propagation
```swift
try await container.start() // Throws TestcontainersError
```

## Memory Management & Cleanup

**Reference Semantics**: Container and network objects are classes (reference types)

**Cleanup Mechanisms**:
1. **Manual**: Call `stop()` and `delete()` explicitly
2. **Scoped**: Use Swift's `defer` statement
   ```swift
   defer { try? await container.stop() }
   ```
3. **Resource Reaper**: Orphaned containers are cleaned up by Docker

**Best Practice**:
```swift
let container = try await builder.buildAsync()
try await container.start()
defer { try? await container.stop() }
// Use container...
```

## Docker Endpoint Detection

**Auto-detection Strategy**:
1. Try Unix socket at `/var/run/docker.sock` (macOS/Linux)
2. Try user-local Docker socket (macOS)
3. Fall back to TCP at `localhost:2375`

**Configuration**: Can be overridden via `Testcontainers.configure()`

## Port Mapping

**Port Allocation**:
- Automatic random port assignment via `assignRandomHostPort: true`
- Prevents port conflicts in test environments
- Mapped port retrieved at runtime via `getMappedPort()`

**Port Format**: Internally stored as `"port/protocol"` (e.g., "5432/tcp")

## Network Communication

**Network Modes**:
- **Host Network**: Direct host access (simple but not isolated)
- **Bridge Network**: Custom networks for isolated container communication
- **Container Networks**: Inter-container DNS via service names

**Pattern**: Prefer bridge networks for test isolation
```swift
.withNetwork(network)
.withNetworkAliases(["database"])
```

## Extension Architecture

**Adding New Modules**:
1. Create new container class in `Modules.swift`
2. Implement builder pattern for configuration
3. Provide service-specific connection methods
4. Add tests demonstrating usage
5. Document with examples

**Example Structure**:
```swift
public class NewServiceContainer {
    private let builder: ContainerBuilder
    
    public init(version: String) {
        self.builder = ContainerBuilder("image:\(version)")
    }
    
    public func start() async throws -> NewServiceReference {
        // Configuration and startup
    }
}
```

## Testing Strategy

**Test Organization**:
- Unit tests for models and error handling
- Integration tests with real Docker containers
- Module-specific tests validating defaults and APIs

**Test Patterns**:
- Async test methods using `async throws`
- Setup/teardown for container lifecycle
- Defer for cleanup ensuring test isolation

## Performance Considerations

1. **Lazy Docker Client Initialization**: Single instance per endpoint
2. **Connection Pooling**: URLSession reuses connections
3. **Concurrent Container Operations**: Async/await enables parallel container starts
4. **Timeout Configuration**: Customizable per wait strategy

## Future Enhancements

1. **Resource Reaper**: Automatic cleanup of orphaned containers
2. **Container Reuse**: Persist and reuse containers across test runs
3. **Compose Support**: Multi-container orchestration from docker-compose
4. **Custom Wait Strategies**: User-provided timeout and retry logic
5. **CI/CD Integration**: Special handling for GitHub Actions, GitLab CI
6. **Docker Compose Integration**: Deploy multi-container environments
7. **Volume Management**: Data persistence and volume mounting
8. **Health Checks**: Built-in health check monitoring

## File Structure

```
testcontainers-swift/
├── Package.swift                 # Swift Package manifest
├── README.md                     # User documentation
├── ARCHITECTURE.md              # This file
├── CONTRIBUTING.md              # Contribution guidelines
├── LICENSE                      # MIT License
├── Sources/
│   ├── Models.swift            # Data structures
│   ├── DockerClient.swift       # Docker API client
│   ├── Container.swift          # Container protocol & builder
│   ├── WaitStrategy.swift       # Wait strategies
│   ├── Network.swift            # Network management
│   └── Modules.swift            # Pre-configured containers
├── Examples/
│   └── main.swift               # Usage examples
├── Tests/
│   └── TestcontainersTests.swift # Test suite
└── .gitignore                   # Git ignore rules
```

## References

- [Docker API Documentation](https://docs.docker.com/engine/api/)
- [Swift Evolution - Async/Await](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md)
- [Testcontainers Java](https://github.com/testcontainers/testcontainers-java)
- [Testcontainers .NET](https://github.com/testcontainers/testcontainers-dotnet)
