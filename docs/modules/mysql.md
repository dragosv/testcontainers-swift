# MySQL

## Introduction

The Testcontainers module for MySQL provides a pre-configured container for running a MySQL database instance in your tests. It uses the official [`mysql`](https://hub.docker.com/_/mysql) Docker image.

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

final class MySqlTests: XCTestCase {
    func testMySqlConnection() async throws {
        let ref = try await MySqlContainer()
            .withDatabase("testdb")
            .withUsername("admin")
            .withPassword("secret")
            .start()

        defer {
            Task { try? await ref.stop() }
        }

        let connectionString = try ref.getConnectionString()
        // connectionString: "mysql://admin:secret@localhost:XXXXX/testdb"

        // Use connectionString with your MySQL driver
    }
}
```

<!--/codeinclude-->

## Module Reference

### `MySqlContainer`

The `MySqlContainer` class configures and starts a MySQL instance.

#### Initializer

```swift
public init(version: String = "latest")
```

Creates a new MySQL container with the given version tag. The container is pre-configured with:

- **Image**: `mysql:<version>`
- **Port**: `3306` (mapped to a random host port)
- **Default credentials**: username `root`, password `root`, database `test`
- **Environment**: `MYSQL_ROOT_PASSWORD` set to `"root"`

#### Container Options

| Method            | Type     | Default  | Description                       |
|-------------------|----------|:--------:|-----------------------------------|
| `withDatabase`    | `String` | `"test"` | Sets the `MYSQL_DATABASE` env var |
| `withUsername`    | `String` | `"root"` | Sets the `MYSQL_USER` env var     |
| `withPassword`    | `String` | `"root"` | Sets `MYSQL_PASSWORD` (and `MYSQL_ROOT_PASSWORD` when username is `root`) |

All option methods return `MySqlContainer` for fluent chaining.

!!! note

    When the username is `root`, calling `withPassword()` also updates the `MYSQL_ROOT_PASSWORD` environment variable to keep both in sync.

#### Wait Strategy

The module uses a composite wait strategy (applied automatically):

| Strategy | Configuration |
|----------|---------------|
| TCP      | Port `3306` |
| Log      | `"ready for connections"` with 60 s timeout |

Both conditions must be satisfied before the container is considered ready.

#### Start

```swift
public func start() async throws -> MySqlContainerReference
```

Builds the container, starts it, and returns a `MySqlContainerReference`.

### `MySqlContainerReference`

The reference object returned after the container starts.

#### Properties

| Property    | Type        | Description                       |
|-------------|-------------|-----------------------------------|
| `container` | `Container` | The underlying container instance |
| `database`  | `String`    | The configured database name      |
| `username`  | `String`    | The configured username           |
| `password`  | `String`    | The configured password           |
| `port`      | `Int`       | The internal port (`3306`)        |

#### Container Methods

| Method                  | Return Type | Description                            |
|-------------------------|-------------|----------------------------------------|
| `getConnectionString()` | `String`    | Returns a `mysql://` connection URI    |
| `stop()`                | `Void`      | Stops the container (10 s timeout)     |
| `delete()`              | `Void`      | Removes the container                  |

##### Connection string format

```
mysql://<username>:<password>@<host>:<mapped-port>/<database>
```

## Examples

### Default configuration

```swift
let ref = try await MySqlContainer().start()
let connStr = try ref.getConnectionString()
// "mysql://root:root@localhost:XXXXX/test"
```

### Pinned version

```swift
let ref = try await MySqlContainer(version: "8.0")
    .withDatabase("mydb")
    .withUsername("user1")
    .withPassword("pass1")
    .start()
```

### Custom root password

```swift
let ref = try await MySqlContainer()
    .withPassword("strongpassword")
    .start()

// Uses root user with the new password
let connStr = try ref.getConnectionString()
// "mysql://root:strongpassword@localhost:XXXXX/test"
```
