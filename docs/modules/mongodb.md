# MongoDB

## Introduction

The Testcontainers module for MongoDB provides a pre-configured container for running a MongoDB instance in your tests. It uses the official [`mongo`](https://hub.docker.com/_/mongo) Docker image.

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

final class MongoDbTests: XCTestCase {
    func testMongoDbConnection() async throws {
        let ref = try await MongoDbContainer()
            .withUsername("testuser")
            .withPassword("testpass")
            .start()

        defer {
            Task { try? await ref.stop() }
        }

        let connectionString = try ref.getConnectionString()
        // connectionString: "mongodb://testuser:testpass@localhost:XXXXX/"

        // Use connectionString with your MongoDB driver
    }
}
```

<!--/codeinclude-->

## Module Reference

### `MongoDbContainer`

The `MongoDbContainer` class configures and starts a MongoDB instance.

#### Initializer

```swift
public init(version: String = "latest")
```

Creates a new MongoDB container with the given version tag. The container is pre-configured with:

- **Image**: `mongo:<version>`
- **Port**: `27017` (mapped to a random host port)
- **Default credentials**: username `admin`, password `admin`
- **Environment**: `MONGO_INITDB_ROOT_USERNAME` and `MONGO_INITDB_ROOT_PASSWORD` set to `"admin"`

#### Container Options

| Method          | Type     | Default   | Description                                  |
|-----------------|----------|:---------:|----------------------------------------------|
| `withUsername`  | `String` | `"admin"` | Sets the `MONGO_INITDB_ROOT_USERNAME` env var |
| `withPassword`  | `String` | `"admin"` | Sets the `MONGO_INITDB_ROOT_PASSWORD` env var |

All option methods return `MongoDbContainer` for fluent chaining.

!!! note

    Unlike the PostgreSQL and MySQL modules, MongoDB does not have a `withDatabase()` method. The default MongoDB behavior creates an `admin` database. To use a specific database, specify it through your MongoDB client after connecting.

#### Wait Strategy

The module uses a single wait strategy (applied automatically):

| Strategy | Configuration |
|----------|---------------|
| HTTP     | Port `27017` with 60 s timeout |

#### Start

```swift
public func start() async throws -> MongoDbContainerReference
```

Builds the container, starts it, and returns a `MongoDbContainerReference`.

### `MongoDbContainerReference`

The reference object returned after the container starts.

#### Properties

| Property    | Type        | Description                       |
|-------------|-------------|-----------------------------------|
| `container` | `Container` | The underlying container instance |
| `username`  | `String`    | The configured username           |
| `password`  | `String`    | The configured password           |
| `port`      | `Int`       | The internal port (`27017`)       |

#### Container Methods

| Method                  | Return Type | Description                             |
|-------------------------|-------------|-----------------------------------------|
| `getConnectionString()` | `String`    | Returns a `mongodb://` connection URI   |
| `stop()`                | `Void`      | Stops the container (10 s timeout)      |
| `delete()`              | `Void`      | Removes the container                   |

##### Connection string format

```
mongodb://<username>:<password>@<host>:<mapped-port>/
```

## Examples

### Default configuration

```swift
let ref = try await MongoDbContainer().start()
let connStr = try ref.getConnectionString()
// "mongodb://admin:admin@localhost:XXXXX/"
```

### Pinned version

```swift
let ref = try await MongoDbContainer(version: "7")
    .withUsername("myuser")
    .withPassword("mypass")
    .start()
```

### Connecting to a specific database

```swift
let ref = try await MongoDbContainer().start()
let baseConnStr = try ref.getConnectionString()
// Append the database name for your driver:
let connStr = baseConnStr + "myDatabase?authSource=admin"
// "mongodb://admin:admin@localhost:XXXXX/myDatabase?authSource=admin"
```
