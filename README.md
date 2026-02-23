[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=develop&repo=1163891557&machine=standardLinux32gb&devcontainer_path=.devcontainer%2Fdevcontainer.json&location=EastUs)


[![CI/CD](https://github.com/dragosv/testcontainers-swift/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dragosv/testcontainers-swift/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/dragosv/testcontainers-swift/branch/main/graph/badge.svg)](https://codecov.io/gh/dragosv/testcontainers-swift)
[![Language](https://img.shields.io/badge/Swift-6.1-brightgreen.svg)](http://swift.org)
[![Docker](https://img.shields.io/badge/Docker%20Engine%20API-%20%201.44-blue)](https://docs.docker.com/engine/api/v1.44/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=shields)](http://makeapullrequest.com)

# Testcontainers for Swift

A lightweight Swift library for writing tests with throwaway Docker containers, inspired by [testcontainers-dotnet](https://github.com/testcontainers/testcontainers-dotnet).

## Requirements

- Swift 6.1+, macOS 13.0+ (or Linux)
- Docker or Docker Desktop running

## Installation

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/dragosv/testcontainers-swift.git", from: "0.1.0")
```

## Quick Start

See [QUICKSTART.md](QUICKSTART.md) for a step-by-step guide.

```swift
import Testcontainers

let container = try await ContainerBuilder("nginx:latest")
    .withPortBinding(80, assignRandomHostPort: true)
    .withWaitStrategy(Wait.http(path: "/", port: 80))
    .buildAsync()

try await container.start()
defer { Task { try? await container.stop() } }

let port = try container.getMappedPort(80)
```

## Modules

Pre-configured containers for common services — each exposes a `getConnectionString()` convenience method:

| Module | Image |
|--------|-------|
| `PostgresContainer` | `postgres` |
| `MySqlContainer` | `mysql` |
| `RedisContainer` | `redis` |
| `MongoDbContainer` | `mongo` |
| `MsSqlContainer` | `mcr.microsoft.com/mssql/server` |
| `RabbitMqContainer` | `rabbitmq` |
| `KafkaContainer` | `confluentinc/cp-kafka` |
| `ElasticsearchContainer` | `elasticsearch` |
| `AzuriteContainer` | `mcr.microsoft.com/azure-storage/azurite` |
| `LocalStackContainer` | `localstack/localstack` |

```swift
let postgres = try await PostgresContainer().withDatabase("testdb").start()
let connectionString = try postgres.getConnectionString()
```

## Wait Strategies

```swift
Wait.http(port: 8080)          // HTTP 2xx response
Wait.tcp(port: 5432)           // TCP port open
Wait.log(message: "started")  // Log line match
Wait.exec(command: ["pg_isready"])
Wait.all(Wait.tcp(port: 5432), Wait.http(port: 8080))
```

## XCTest Integration

```swift
final class DatabaseTests: XCTestCase {
    var postgres: PostgresContainerReference!

    override func setUp() async throws {
        postgres = try await PostgresContainer().withDatabase("testdb").start()
    }

    override func tearDown() async throws {
        try await postgres.stop()
    }

    func testConnection() async throws {
        let connectionString = try postgres.getConnectionString()
        XCTAssertNotNil(connectionString)
    }
}
```

## Documentation

| Document | Description |
|----------|-------------|
| [QUICKSTART.md](QUICKSTART.md) | 5-minute getting-started guide |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Design decisions and component overview |
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | Full feature inventory and implementation stats |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [Examples/main.swift](Examples/main.swift) | Runnable usage examples |

## Contributing

Contributions are welcome — please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## Acknowledgments

This project includes code derived from [docker-client-swift](https://github.com/alexsteinerde/docker-client-swift) by [Alexander Steiner](https://github.com/alexsteinerde), licensed under MIT.

## License

MIT — see [LICENSE](LICENSE).

## Support

[Slack](https://slack.testcontainers.org/) · [Stack Overflow](https://stackoverflow.com/questions/tagged/testcontainers) · [GitHub Issues](https://github.com/dragosv/testcontainers-swift/issues/)

---

Copyright © 2026 Dragos Varovici and contributors.
