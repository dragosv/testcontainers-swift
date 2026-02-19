[![Project Status: Active - The project has reached a stable, usable state and is being actively developed.](http://www.repostatus.org/badges/latest/active.svg)](http://www.repostatus.org/#active) [![Build Status](https://img.shields.io/travis/com/dragosv/testcontainers-swift/master.svg?label=linux+build)](https://https://app.travis-ci.com/github/dragosv/testcontainers-swift)
[![Build status](https://github.com/dragosv/testcontainers-swift/actions/workflows/main.yml/badge.svg)](https://github.com/dragosv/testcontainers-swift/actions/workflows/main.yml)
[![codecov](https://codecov.io/gh/dragosv/testcontainers-swift/branch/master/graph/badge.svg)](https://codecov.io/gh/dragosv/testcontainers-swift)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=shields)](http://makeapullrequest.com)
[![Join the chat at https://gitter.im/testcontainers-swift/Lobby](https://badges.gitter.im/testcontainers-swift/Lobby.svg)](https://gitter.im/testcontainers-swift/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) 
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fdragosv%2Ftestcontainers-swift.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Fdragosv%2Ftestcontainers-swift?ref=badge_shield)
[![Language](https://img.shields.io/badge/Swift-6.0-brightgreen.svg)](http://swift.org)
[![Docker](https://img.shields.io/badge/Docker%20Engine%20API-%20%201.44-blue)](https://docs.docker.com/engine/api/v1.44/)

# Testcontainers for Swift

A lightweight Swift library to support tests with throwaway instances of Docker containers. Based on the architecture of [testcontainers-dotnet](https://github.com/testcontainers/testcontainers-dotnet).

## Features

- **Easy Container Management**: Start, stop, and manage Docker containers in your tests
- **Fluent Builder API**: Chainable configuration for containers
- **Wait Strategies**: Wait for services to be ready (HTTP, TCP, logs, etc.)
- **Port Binding**: Automatic random port assignment to prevent conflicts
- **Network Support**: Create and manage Docker networks
- **Pre-configured Modules**: Ready-to-use containers for popular services (PostgreSQL, MySQL, Redis, etc.)
- **Automatic Cleanup**: Resources are automatically cleaned up after tests complete
- **Cross-Platform**: Works on macOS, Linux, and Windows (with Docker Desktop)

## Requirements

- Swift 6.0+
- Docker or Docker Desktop running with Docker API available
- macOS 13.0+, iOS 16.0+, tvOS 16.0+, or watchOS 9.0+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/dragosv/testcontainers-swift.git", from: "0.1.0")
```

Or in Xcode: File → Add Packages → Enter the repository URL

## Quick Start

### Basic Example

```swift
import Testcontainers

// Create a container
let container = ContainerBuilder("testcontainers/helloworld:1.3.0")
    .withPortBinding(8080, assignRandomHostPort: true)
    .withWaitStrategy(Wait.http(port: 8080))
    .build()

// Start the container
try await container.start()

// Use the container
let port = container.getMappedPort(8080)
print("Container is running on port: \(port)")

// Stop the container (automatic when using 'defer')
defer { try? await container.stop() }
```

### Using Modules

```swift
import Testcontainers

// PostgreSQL container with pre-configured defaults
let postgres = try await PostgresContainer()
    .withDatabase("testdb")
    .withUsername("postgres")
    .withPassword("password")
    .start()

let connectionString = postgres.getConnectionString()
print("Connected to: \(connectionString)")
```

## Architecture

The library follows the same architecture as testcontainers-dotnet with Swift-specific adaptations:

- **DockerClient**: Low-level Docker API communication
- **Container**: Manages container lifecycle
- **ContainerBuilder**: Fluent API for configuration
- **WaitStrategy**: Defines readiness conditions
- **Network**: Docker network management
- **Modules**: Pre-configured containers for specific services

## Core Components

### Container Builder

Create and configure containers with a fluent API:

```swift
let container = ContainerBuilder("nginx:latest")
    .withName("my-nginx")
    .withEnvironment(["NGINX_HOST": "localhost"])
    .withPortBinding(80, assignRandomHostPort: true)
    .withPortBinding(443, assignRandomHostPort: true)
    .withWaitStrategy(Wait.http(path: "/", port: 80))
    .withLabel("service", "web")
    .build()

try await container.start()
```

### Wait Strategies

Wait for containers to be ready:

```swift
// Wait for HTTP endpoint
.withWaitStrategy(Wait.http(port: 8080))
.withWaitStrategy(Wait.http(path: "/health", port: 8080))

// Wait for TCP port
.withWaitStrategy(Wait.tcp(port: 5432))

// Wait for log message
.withWaitStrategy(Wait.log(message: "Server started"))

// Wait for command to succeed
.withWaitStrategy(Wait.exec(command: ["echo", "ready"]))

// Custom wait strategy
.withWaitStrategy(Wait.custom { container in
    // Your custom logic
})

// Combine strategies
.withWaitStrategy(Wait.all(Wait.tcp(port: 5432), Wait.http(port: 8080)))
```

### Port Binding

Automatically manage port mappings:

```swift
// Bind to random host port
.withPortBinding(8080, assignRandomHostPort: true)

// Bind to specific host port
.withPortBinding(hostPort: 8080, containerPort: 8080)

// Retrieve mapped port
let port = container.getMappedPort(8080)
```

### Networks

Create custom networks for container communication:

```swift
// Create a network
let network = try await NetworkBuilder("my-network").build()

// Connect containers to network
let container = ContainerBuilder("postgres:15")
    .withNetwork(network)
    .withNetworkAlias("postgres")
    .build()

try await container.start()
```

### Modules

Pre-configured containers for common services:

```swift
// PostgreSQL
let postgres = try await PostgresContainer()
    .withVersion("15")
    .withDatabase("testdb")
    .start()

// MySQL
let mysql = try await MySqlContainer()
    .withVersion("8.0")
    .withDatabase("testdb")
    .start()

// Redis
let redis = try await RedisContainer()
    .withVersion("7")
    .start()

// MongoDB
let mongo = try await MongoDbContainer()
    .withVersion("6.0")
    .start()

// Connection strings
let pgConnectionString = postgres.getConnectionString()
let mysqlConnectionString = mysql.getConnectionString()
let redisURL = redis.getRedisURL()
```

## Testing with XCTest

```swift
import XCTest
import Testcontainers

final class DatabaseTests: XCTestCase {
    var postgres: PostgresContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        postgres = try await PostgresContainer()
            .withDatabase("testdb")
            .start()
    }
    
    override func tearDown() async throws {
        try await postgres.stop()
        try await super.tearDown()
    }
    
    func testDatabaseConnection() async throws {
        let connectionString = postgres.getConnectionString()
        XCTAssertNotNil(connectionString)
        // Your test logic here
    }
}
```

## Configuration

### Docker Endpoint

By default, Testcontainers auto-detects your Docker installation. To specify a custom Docker endpoint:

```swift
// Setup before creating containers
Testcontainers.configure {
    $0.dockerEndpoint = "unix:///var/run/docker.sock"
    // or for remote Docker
    $0.dockerEndpoint = "tcp://docker-host:2375"
}
```

### Resource Reuse

Containers can be reused across tests:

```swift
let container = ContainerBuilder("postgres:15")
    .withReuse(true)
    .withName("postgres-reusable")
    .build()

// Container will be reused if it already exists
try await container.start()
```

### Cleanup

Automatic cleanup on container disposal:

```swift
// Manual cleanup
try await container.stop()
try await container.delete()

// Automatic cleanup with defer
defer { Task { try? await container.stop() } }
```

## Examples

See the [Examples](Examples/) directory for complete examples:

- Basic container usage
- Multiple container orchestration
- Custom wait strategies
- Module-specific examples
- Network communication between containers

## Best Practices

1. **Use defer for cleanup**: Ensures containers are stopped even if tests fail
   ```swift
   defer { Task { try? await container.stop() } }
   ```

2. **Use modules when available**: They provide proper defaults and connection strings
3. **Set appropriate wait strategies**: Don't rely on fixed delays
4. **Name your containers**: Helps with debugging
5. **Use networks**: Prefer networks to port exposure for inter-container communication

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - See [LICENSE](LICENSE) file for details

## Related Projects

- [Testcontainers](https://www.testcontainers.org/) - Main project
- [testcontainers-dotnet](https://github.com/testcontainers/testcontainers-dotnet) - .NET implementation
- [testcontainers-java](https://github.com/testcontainers/testcontainers-java) - Java implementation
- [testcontainers-go](https://github.com/testcontainers/testcontainers-go) - Go implementation
- [testcontainers-python](https://github.com/testcontainers/testcontainers-python) - Python implementation

## Support

- [Slack](https://slack.testcontainers.org/)


## Acknowledgments

* **[Docker Client for Swift]**: This project includes significant code from [Docker Client](https://github.com/alexsteinerde/docker-client-swift), originally developed by [Alexander Steiner](https://github.com/alexsteinerde), now archived.
* The logic for [Docker Client] is derived from their work, which is licensed under the [MIT] license.

## Copyright

Copyright (c) 2026 Dragos Varovici and other authors.

## Support
----

Join our [Slack Workspace][slack-workspace] | [Testcontainers OSS][testcontainers-oss] | [Testcontainers Cloud][testcontainers-cloud] | [GitHub Issues](testcontainers-swift-github-issues) | [Stack Overflow] [testcontainers-stack-overflow]
| [Stack Overflow](https://stackoverflow.com/questions/tagged/testcontainers)


[slack-workspace]: https://slack.testcontainers.org/
[testcontainers-oss]: https://www.testcontainers.org/
[testcontainers-cloud]: https://www.testcontainers.cloud/
[testcontainers-swift-github-issues]: https://github.com/dragosv/testcontainers-swift/issues/
[testcontainers-stack-overflow]: https://stackoverflow.com/questions/tagged/testcontainers

