# Connection strings

Pre-configured container [modules](../modules/index.md) provide a `getConnectionString()` method (or equivalent) that returns a ready-to-use connection string. This eliminates the need to manually construct connection URLs from host, port, and credentials.

## How it works

After starting a module container, call `getConnectionString()` on the returned reference object. The connection string includes the mapped host, the random port assigned by Docker, and any configured credentials.

```swift
let ref = try await PostgresContainer()
    .withDatabase("mydb")
    .withUsername("user")
    .withPassword("pass")
    .start()

let connectionString = try ref.getConnectionString()
// postgresql://user:pass@localhost:55432/mydb
```

## Available connection strings

### PostgreSQL

```swift
let ref = try await PostgresContainer()
    .withDatabase("testdb")
    .withUsername("admin")
    .withPassword("secret")
    .start()

let url = try ref.getConnectionString()
// Format: postgresql://<username>:<password>@<host>:<port>/<database>
```

### MySQL

```swift
let ref = try await MySqlContainer()
    .withDatabase("testdb")
    .withUsername("admin")
    .withPassword("secret")
    .start()

let url = try ref.getConnectionString()
// Format: mysql://<username>:<password>@<host>:<port>/<database>
```

### Redis

```swift
let ref = try await RedisContainer().start()

let url = try ref.getRedisURL()
// Format: redis://<host>:<port>
```

### MongoDB

```swift
let ref = try await MongoDbContainer()
    .withUsername("admin")
    .withPassword("secret")
    .start()

let url = try ref.getConnectionString()
// Format: mongodb://<username>:<password>@<host>:<port>/
```

## Using connection strings in tests

```swift
import XCTest
import Testcontainers

final class DatabaseTests: XCTestCase {
    var postgresRef: PostgresContainerReference?

    override func setUp() async throws {
        postgresRef = try await PostgresContainer()
            .withDatabase("testdb")
            .withUsername("admin")
            .withPassword("secret")
            .start()
    }

    override func tearDown() async throws {
        try? await postgresRef?.container.stop(timeout: 10)
    }

    func testConnection() async throws {
        let connectionString = try postgresRef!.getConnectionString()
        XCTAssertTrue(connectionString.hasPrefix("postgresql://"))
    }
}
```

!!! tip

    Connection strings automatically use the correct mapped host port, so you never need to worry about port conflicts.
