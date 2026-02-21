# PostgreSQL

## Introduction

The Testcontainers module for PostgreSQL provides a pre-configured container for running a PostgreSQL database instance in your tests. It uses the official [`postgres`](https://hub.docker.com/_/postgres) Docker image.

## Adding the dependency

Add Testcontainers to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dragosv/testcontainers-swift.git", from: "0.1.0"),
],
targets: [
    .testTarget(
        name: "MyAppTests",
        dependencies: [
            .product(name: "Testcontainers", package: "testcontainers-swift"),
        ]
    ),
]
```

## Usage example

<!--codeinclude-->

```swift
import Testcontainers
import XCTest

final class PostgresTests: XCTestCase {
    func testPostgresConnection() async throws {
        let ref = try await PostgresContainer()
            .withDatabase("testdb")
            .withUsername("admin")
            .withPassword("secret")
            .start()

        defer {
            Task { try? await ref.stop() }
        }

        let connectionString = try ref.getConnectionString()
        // connectionString: "postgresql://admin:secret@localhost:XXXXX/testdb"

        // Use connectionString with your PostgreSQL driver
    }
}
```

<!--/codeinclude-->

## Module Reference

### `PostgresContainer`

The `PostgresContainer` class configures and starts a PostgreSQL instance.

#### Initializer

```swift
public init(version: String = "latest")
```

Creates a new PostgreSQL container with the given version tag. The container is pre-configured with:

- **Image**: `postgres:<version>`
- **Port**: `5432` (mapped to a random host port)
- **Default credentials**: username `postgres`, password `postgres`, database `postgres`

#### Container Options

| Method            | Type     | Default      | Description                       |
|-------------------|----------|:------------:|-----------------------------------|
| `withDatabase`    | `String` | `"postgres"` | Sets the `POSTGRES_DB` env var    |
| `withUsername`    | `String` | `"postgres"` | Sets the `POSTGRES_USER` env var  |
| `withPassword`    | `String` | `"postgres"` | Sets the `POSTGRES_PASSWORD` env var |

All option methods return `PostgresContainer` for fluent chaining.

#### Wait Strategy

The module uses a composite wait strategy (applied automatically):

| Strategy | Configuration |
|----------|---------------|
| TCP      | Port `5432` |
| Log      | `"database system is ready to accept connections"` with 60 s timeout |

Both conditions must be satisfied before the container is considered ready.

#### Start

```swift
public func start() async throws -> PostgresContainerReference
```

Builds the container, starts it, and returns a `PostgresContainerReference`.

### `PostgresContainerReference`

The reference object returned after the container starts.

#### Properties

| Property    | Type        | Description                       |
|-------------|-------------|-----------------------------------|
| `container` | `Container` | The underlying container instance |
| `database`  | `String`    | The configured database name      |
| `username`  | `String`    | The configured username           |
| `password`  | `String`    | The configured password           |
| `port`      | `Int`       | The internal port (`5432`)        |

#### Container Methods

| Method                  | Return Type | Description                               |
|-------------------------|-------------|-------------------------------------------|
| `getConnectionString()` | `String`    | Returns a `postgresql://` connection URI  |
| `stop()`                | `Void`      | Stops the container (10 s timeout)        |
| `delete()`              | `Void`      | Removes the container                     |

##### Connection string format

```
postgresql://<username>:<password>@<host>:<mapped-port>/<database>
```

## Examples

### Default configuration

```swift
let ref = try await PostgresContainer().start()
let connStr = try ref.getConnectionString()
// "postgresql://postgres:postgres@localhost:XXXXX/postgres"
```

### Pinned version

```swift
let ref = try await PostgresContainer(version: "16")
    .withDatabase("mydb")
    .withUsername("user1")
    .withPassword("pass1")
    .start()
```

### Using a custom network (generic builder)

```swift
let network = try await NetworkBuilder("pg-net").build()

let container = try await ContainerBuilder("postgres:16")
    .withNetwork(network)
    .withNetworkAliases(["postgres"])
    .withEnvironment("POSTGRES_PASSWORD", "postgres")
    .withPortBinding(5432, assignRandomHostPort: true)
    .withWaitStrategy(Wait.tcp(port: 5432))
    .buildAsync()

try await container.start()

let host = container.host ?? "localhost"
let mappedPort = try container.getMappedPort(5432)
let connStr = "postgresql://postgres:postgres@\(host):\(mappedPort)/postgres"
```
