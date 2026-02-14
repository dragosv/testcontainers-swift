# Quick Start Guide

Get started with Testcontainers Swift in 5 minutes.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dragosv/testcontainers-swift.git", from: "0.1.0")
]
```

Or in Xcode:
1. File → Add Packages
2. Enter: `https://github.com/testcontainers/testcontainers-swift.git`
3. Select version and add to project

## Prerequisites

- Docker installed and running
- Swift 6.0 or later
- macOS, Linux, iOS, tvOS, or watchOS

## Basic Example

```swift
import Testcontainers

// Create a PostgreSQL container
let postgres = try await PostgresContainer()
    .withDatabase("mydb")
    .withUsername("user")
    .withPassword("password")
    .start()

// Use the connection string
let connectionString = try postgres.getConnectionString()
print("Connected to: \(connectionString)")

// Clean up
try await postgres.stop()
```

## Starting a Custom Container

```swift
let container = try await ContainerBuilder("nginx:latest")
    .withName("my-web-server")
    .withPortBinding(80, assignRandomHostPort: true)
    .withWaitStrategy(.tcp(port: 80, timeout: 30))
    .buildAsync()

try await container.start()

let port = try container.getMappedPort(80)
print("Nginx running on port: \(port)")

try await container.stop()
```

## Using with XCTest

```swift
import XCTest
import Testcontainers

class DatabaseTests: XCTestCase {
    var db: PostgresContainerReference?
    
    override func setUp() async throws {
        try await super.setUp()
        db = try await PostgresContainer()
            .withDatabase("testdb")
            .start()
    }
    
    override func tearDown() async throws {
        try await db?.stop()
        try await super.tearDown()
    }
    
    func testDatabase() throws {
        let connectionString = try db?.getConnectionString()
        XCTAssertNotNil(connectionString)
    }
}
```

## Available Modules

### PostgreSQL

```swift
let postgres = try await PostgresContainer(version: "15")
    .withDatabase("testdb")
    .start()

let url = try postgres.getConnectionString()
```

### MySQL

```swift
let mysql = try await MySqlContainer(version: "8.0")
    .withDatabase("testdb")
    .start()

let url = try mysql.getConnectionString()
```

### Redis

```swift
let redis = try await RedisContainer(version: "7")
    .start()

let url = try redis.getRedisURL()
```

### MongoDB

```swift
let mongo = try await MongoDbContainer(version: "6.0")
    .start()

let url = try mongo.getConnectionString()
```

## Common Patterns

### Using defer for cleanup  

```swift
let container = try await builder.buildAsync()
try await container.start()
defer { try? await container.stop() }

// Use container...
```

### Custom wait strategies

```swift
try await container
    .withWaitStrategy(
        .all(
            .tcp(port: 5432),
            .log(message: "database system is ready")
        )
    )
    .buildAsync()
```

### Environment-specific setup

```swift
let builder = ContainerBuilder("postgres:15")
    .withEnvironment([
        "POSTGRES_DB": "testdb",
        "POSTGRES_USER": "testuser",
        "POSTGRES_PASSWORD": "testpass"
    ])
```

### Network communication

```swift
let network = try await NetworkBuilder("app-network").build()

let db = try await ContainerBuilder("postgres:15")
    .withNetwork(network)
    .withNetworkAliases(["database"])
    .buildAsync()

let app = try await ContainerBuilder("myapp:1.0")
    .withNetwork(network)
    .buildAsync()

// Now "app" can reach database at hostname "database"
```

## Troubleshooting

### Docker not found

**Issue**: `TestcontainersError.dockerNotAvailable`

**Solution**: Ensure Docker is installed and running:
```bash
docker ps
```

### Port already in use

**Solution**: Use random port assignment:
```swift
.withPortBinding(8080, assignRandomHostPort: true)
```

### Container won't start

**Solution**: Check the logs:
```swift
let logs = try await container.getLogs()
print(logs)
```

### Wait strategy timeout

**Solution**: Increase timeout or change strategy:
```swift
.withWaitStrategy(.tcp(port: 5432, timeout: 120))
```

## Next Steps

- Read [ARCHITECTURE.md](ARCHITECTURE.md) for design details
- Check [Examples](Examples/) for more use cases
- See [Tests](Tests/) for integration patterns
- Visit [Contributing](CONTRIBUTING.md) to contribute

## Getting Help

- Open an issue on GitHub
- Check existing issues and discussions
- Ask on Stack Overflow with `testcontainers` tag
- Join the Testcontainers Slack
