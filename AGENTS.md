# Agents.md

## AI Agent Configuration for testcontainers-swift

This document defines specialized AI agents for working with the testcontainers-swift project. These agents can be used with AI-powered development tools to automate common tasks.

---

## Available Agents

### 1. Plan Agent

**Purpose**: Research and outline multistep implementation plans for new features or refactoring tasks.

**Use Cases**:
- Planning new container module implementations
- Designing architectural changes
- Breaking down complex features into tasks
- Creating migration strategies

**Example Tasks**:
- "Plan the implementation of a Kafka container module"
- "Design a strategy for adding volume mounting support"
- "Outline the steps to implement container reuse"

---

### 2. Container Module Agent

**Purpose**: Create new pre-configured container modules following the established patterns.

**Capabilities**:
- Generate new module classes (e.g., ElasticsearchContainer, KafkaContainer)
- Create corresponding reference classes
- Add proper documentation
- Follow existing code conventions

**Template Pattern**:
```swift
public class <Service>Container {
    private let builder: ContainerBuilder
    // Configuration properties
    
    public init(version: String = "latest") { ... }
    
    @discardableResult
    public func with<Property>(_ value: Type) -> <Service>Container { ... }
    
    public func start() async throws -> <Service>ContainerReference { ... }
}

public class <Service>ContainerReference: @unchecked Sendable {
    public let container: Container
    // Service-specific properties
    
    public func getConnectionString() throws -> String { ... }
    public func stop() async throws { ... }
    public func delete() async throws { ... }
}
```

**Existing Modules to Reference**:
- `Sources/Testcontainers/Modules.swift`: PostgresContainer, MySqlContainer, RedisContainer, MongoDbContainer

---

### 3. Wait Strategy Agent

**Purpose**: Implement custom wait strategies for container readiness checks.

**Capabilities**:
- Create new WaitStrategy implementations
- Add convenience methods to the Wait class
- Handle platform-specific logic (macOS vs Linux)

**Template Pattern**:
```swift
public struct <Name>WaitStrategy: WaitStrategy {
    // Configuration properties
    public let timeout: TimeInterval
    public let interval: TimeInterval
    
    public init(...) { ... }
    
    public func waitUntilReady(container: Container, client: DockerClient) async throws {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            // Check condition
            // Return if ready
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        throw TestcontainersError.waitStrategyFailed("...")
    }
}
```

**Reference File**: `Sources/Testcontainers/WaitStrategy.swift`

---

### 4. Test Agent

**Purpose**: Generate comprehensive test cases for new features.

**Capabilities**:
- Create XCTest test classes
- Write async test methods
- Generate setup/teardown for containers
- Add assertions for connection strings and states

**Template Pattern**:
```swift
final class <Feature>Tests: XCTestCase {
    var container: <Type>?
    
    override func setUp() async throws {
        try await super.setUp()
        container = try await <Container>().start()
    }
    
    override func tearDown() async throws {
        try await container?.stop()
        try await super.tearDown()
    }
    
    func test<Scenario>() async throws {
        // Test implementation
        XCTAssertNotNil(...)
    }
}
```

**Reference File**: `Tests/TestcontainersTests.swift`

---

### 5. Documentation Agent

**Purpose**: Generate and update project documentation.

**Capabilities**:
- Update README.md with new features
- Add API documentation comments
- Create usage examples
- Update CHANGELOG.md

**Documentation Style**:
```swift
/// Brief description of the class/method.
/// - Parameters:
///   - param1: Description of parameter.
///   - param2: Description of parameter.
/// - Returns: Description of return value.
/// - Throws: Description of possible errors.
public func methodName(param1: Type, param2: Type) throws -> ReturnType
```

---

### 6. CI/CD Agent

**Purpose**: Maintain and update GitHub Actions workflows.

**Capabilities**:
- Update CI/CD configurations
- Add new workflow jobs
- Configure code coverage
- Set up release automation

**Workflow Files**:
- `.github/workflows/ci.yml` - Main CI pipeline
- `.github/workflows/coverage.yml` - macOS coverage
- `.github/workflows/linux-coverage.yml` - Linux coverage
- `.github/workflows/release.yml` - Release automation

---

### 7. Docker API Agent

**Purpose**: Extend Docker API capabilities in DockerClientSwift.

**Capabilities**:
- Add new Docker API endpoints
- Create raw endpoint implementations
- Handle response parsing
- Implement error handling

**Reference Files**:
- `Sources/Testcontainers/RawEndpoints.swift`
- `Sources/Testcontainers/DockerClient.swift`
- `Sources/DockerClientSwift/APIs/`

---

## Project Context for Agents

### Technology Stack
- **Language**: Swift 6.1+
- **Package Manager**: Swift Package Manager
- **Testing**: XCTest
- **Concurrency**: async/await, Sendable
- **Dependencies**: swift-nio, async-http-client, swift-log

### Architecture Patterns
- Protocol-oriented design
- Fluent builder pattern
- Strategy pattern for wait conditions
- Singleton for DockerClient
- Reference types for lifecycle management

### Key Files
| File | Purpose |
|------|---------|
| `Package.swift` | Package configuration |
| `Sources/Testcontainers/Container.swift` | Container protocol and builder |
| `Sources/Testcontainers/DockerClient.swift` | Docker API client |
| `Sources/Testcontainers/Modules.swift` | Pre-configured modules |
| `Sources/Testcontainers/WaitStrategy.swift` | Wait strategies |
| `Sources/Testcontainers/Network.swift` | Network management |
| `Sources/Testcontainers/Models.swift` | Data models |
| `Tests/TestcontainersTests.swift` | Test suite |

### Code Conventions
- Use `@discardableResult` for builder methods
- Use `async throws` for I/O operations
- Use `@unchecked Sendable` for thread-safe reference types
- Document all public APIs with `///` comments
- Follow SwiftLint and SwiftFormat rules

### Error Handling
```swift
public enum TestcontainersError: Error {
    case containerNotFound(String)
    case portMappingFailed(Int)
    case waitStrategyFailed(String)
    case networkError(String)
    case dockerError(String)
}
```

---

## Agent Usage Examples

### Creating a New Module
```
Task: Create an Elasticsearch container module with:
- Version configuration
- Cluster name setting
- HTTP port (9200) and transport port (9300)
- HTTP wait strategy on port 9200
- Connection URL helper method
```

### Adding a Wait Strategy
```
Task: Create a database-ready wait strategy that:
- Executes a simple query command
- Retries until successful or timeout
- Works with PostgreSQL and MySQL
```

### Generating Tests
```
Task: Create integration tests for the Redis module that:
- Start a Redis container
- Verify the Redis URL format
- Test basic connectivity
- Clean up after tests
```

### Updating CI/CD
```
Task: Add a workflow job that:
- Runs on pull requests
- Builds the package
- Runs tests with Docker
- Reports coverage to Codecov
```

---

## Best Practices for Agent Tasks

1. **Be Specific**: Provide clear requirements and expected outcomes
2. **Reference Existing Code**: Point to similar implementations for consistency
3. **Include Tests**: Request test coverage for new features
4. **Document Changes**: Ask for documentation updates
5. **Follow Patterns**: Maintain consistency with existing architecture

---

## Contributing Agent Configurations

When adding new agent configurations:

1. Define the agent's purpose clearly
2. List specific capabilities
3. Provide template patterns
4. Reference existing code files
5. Include usage examples

---

## Related Documentation

- [README.md](README.md) - Project overview
- [ARCHITECTURE.md](ARCHITECTURE.md) - System design
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) - Implementation details
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Implementation summary

