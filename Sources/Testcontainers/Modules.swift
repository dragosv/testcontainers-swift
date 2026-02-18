import Foundation

// MARK: - PostgreSQL Container Module

/// A container for PostgreSQL database with pre-configured settings.
public class PostgresContainer {
    private let builder: ContainerBuilder
    private var database: String = "postgres"
    private var username: String = "postgres"
    private var password: String = "postgres"
    private var port: Int = 5432
    private var version: String = "latest"

    /// Initializes a new PostgreSQL container.
    /// - Parameter version: The PostgreSQL version, defaults to "latest".
    public init(version: String = "latest") {
        self.version = version
        let imageName = "postgres:\(version)"
        self.builder = ContainerBuilder(imageName)
            .withName("postgres-\(UUID().uuidString)")
            .withPortBinding(port, assignRandomHostPort: true)
            .withEnvironment("POSTGRES_PASSWORD", "postgres")
    }

    /// Sets the database name.
    /// - Parameter database: The database name.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withDatabase(_ database: String) -> PostgresContainer {
        self.database = database
        builder.withEnvironment("POSTGRES_DB", database)
        return self
    }

    /// Sets the username.
    /// - Parameter username: The username.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withUsername(_ username: String) -> PostgresContainer {
        self.username = username
        builder.withEnvironment("POSTGRES_USER", username)
        return self
    }

    /// Sets the password.
    /// - Parameter password: The password.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withPassword(_ password: String) -> PostgresContainer {
        self.password = password
        builder.withEnvironment("POSTGRES_PASSWORD", password)
        return self
    }

    /// Starts the PostgreSQL container.
    /// - Returns: A reference to the started container.
    /// - Throws: An error if starting the container fails.
    public func start() async throws -> PostgresContainerReference {
        let container = try await builder
            .withWaitStrategy(
                Wait.all(
                    Wait.tcp(port: port),
                    Wait.log(message: "database system is ready to accept connections", timeout: 60)
                )
            )
            .buildAsync()

        try await container.start()

        return PostgresContainerReference(
            container: container,
            database: database,
            username: username,
            password: password,
            port: port
        )
    }
}

/// A reference to a running PostgreSQL container.
public class PostgresContainerReference: @unchecked Sendable {
    /// The underlying container.
    public let container: Container
    /// The database name.
    public let database: String
    /// The username.
    public let username: String
    /// The password.
    public let password: String
    /// The port number.
    public let port: Int

    /// Initializes a new PostgreSQL container reference.
    /// - Parameters:
    ///   - container: The container.
    ///   - database: The database name.
    ///   - username: The username.
    ///   - password: The password.
    ///   - port: The port number.
    init(
        container: Container,
        database: String,
        username: String,
        password: String,
        port: Int)
    {
        self.container = container
        self.database = database
        self.username = username
        self.password = password
        self.port = port
    }

    /// Gets the PostgreSQL connection string.
    /// - Returns: The connection string.
    /// - Throws: An error if the port mapping is not found.
    public func getConnectionString() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(port)
        return "postgresql://\(username):\(password)@\(host):\(mappedPort)/\(database)"
    }

    /// Stops the container.
    /// - Throws: An error if stopping the container fails.
    public func stop() async throws {
        try await container.stop(timeout: 10)
    }

    /// Deletes the container.
    /// - Throws: An error if deleting the container fails.
    public func delete() async throws {
        try await container.delete()
    }
}

// MARK: - MySQL Container Module

/// A container for MySQL database with pre-configured settings.
public class MySqlContainer {
    private let builder: ContainerBuilder
    private var database: String = "test"
    private var username: String = "root"
    private var password: String = "root"
    private var port: Int = 3306
    private var version: String = "latest"

    /// Initializes a new MySQL container.
    /// - Parameter version: The MySQL version, defaults to "latest".
    public init(version: String = "latest") {
        self.version = version
        let imageName = "mysql:\(version)"
        self.builder = ContainerBuilder(imageName)
            .withName("mysql-\(UUID().uuidString)")
            .withPortBinding(port, assignRandomHostPort: true)
            .withEnvironment("MYSQL_ROOT_PASSWORD", "root")
    }

    /// Sets the database name.
    /// - Parameter database: The database name.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withDatabase(_ database: String) -> MySqlContainer {
        self.database = database
        builder.withEnvironment("MYSQL_DATABASE", database)
        return self
    }

    /// Sets the username.
    /// - Parameter username: The username.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withUsername(_ username: String) -> MySqlContainer {
        self.username = username
        builder.withEnvironment("MYSQL_USER", username)
        return self
    }

    /// Sets the password.
    /// - Parameter password: The password.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withPassword(_ password: String) -> MySqlContainer {
        self.password = password
        builder.withEnvironment("MYSQL_PASSWORD", password)
        if username == "root" {
            builder.withEnvironment("MYSQL_ROOT_PASSWORD", password)
        }
        return self
    }

    /// Starts the MySQL container.
    /// - Returns: A reference to the started container.
    /// - Throws: An error if starting the container fails.
    public func start() async throws -> MySqlContainerReference {
        let container = try await builder
            .withWaitStrategy(
                Wait.all(
                    Wait.tcp(port: port),
                    Wait.log(message: "ready for connections", timeout: 60)
                )
            )
            .buildAsync()

        try await container.start()

        return MySqlContainerReference(
            container: container,
            database: database,
            username: username,
            password: password,
            port: port
        )
    }
}

/// A reference to a running MySQL container.
public class MySqlContainerReference: @unchecked Sendable {
    /// The underlying container.
    public let container: Container
    /// The database name.
    public let database: String
    /// The username.
    public let username: String
    /// The password.
    public let password: String
    /// The port number.
    public let port: Int

    /// Initializes a new MySQL container reference.
    /// - Parameters:
    ///   - container: The container.
    ///   - database: The database name.
    ///   - username: The username.
    ///   - password: The password.
    ///   - port: The port number.
    init(
        container: Container,
        database: String,
        username: String,
        password: String,
        port: Int)
    {
        self.container = container
        self.database = database
        self.username = username
        self.password = password
        self.port = port
    }

    /// Gets the MySQL connection string.
    /// - Returns: The connection string.
    /// - Throws: An error if the port mapping is not found.
    public func getConnectionString() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(port)
        return "mysql://\(username):\(password)@\(host):\(mappedPort)/\(database)"
    }

    /// Stops the container.
    /// - Throws: An error if stopping the container fails.
    public func stop() async throws {
        try await container.stop(timeout: 10)
    }

    /// Deletes the container.
    /// - Throws: An error if deleting the container fails.
    public func delete() async throws {
        try await container.delete()
    }
}

// MARK: - Redis Container Module

/// A container for Redis with pre-configured settings.
public class RedisContainer {
    private let builder: ContainerBuilder
    private var port: Int = 6379
    private var version: String = "latest"

    /// Initializes a new Redis container.
    /// - Parameter version: The Redis version, defaults to "latest".
    public init(version: String = "latest") {
        self.version = version
        let imageName = "redis:\(version)"
        self.builder = ContainerBuilder(imageName)
            .withName("redis-\(UUID().uuidString)")
            .withPortBinding(port, assignRandomHostPort: true)
    }

    /// Starts the Redis container.
    /// - Returns: A reference to the started container.
    /// - Throws: An error if starting the container fails.
    public func start() async throws -> RedisContainerReference {
        let container = try await builder
            .withWaitStrategy(
                Wait.http(port: port, timeout: 60)
            )
            .buildAsync()

        try await container.start()

        return RedisContainerReference(
            container: container,
            port: port
        )
    }
}

/// A reference to a running Redis container.
public class RedisContainerReference: @unchecked Sendable {
    /// The underlying container.
    public let container: Container
    /// The port number.
    public let port: Int

    /// Initializes a new Redis container reference.
    /// - Parameters:
    ///   - container: The container.
    ///   - port: The port number.
    init(container: Container, port: Int) {
        self.container = container
        self.port = port
    }

    /// Gets the Redis URL.
    /// - Returns: The Redis URL.
    /// - Throws: An error if the port mapping is not found.
    public func getRedisURL() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(port)
        return "redis://\(host):\(mappedPort)"
    }

    /// Stops the container.
    /// - Throws: An error if stopping the container fails.
    public func stop() async throws {
        try await container.stop(timeout: 10)
    }

    /// Deletes the container.
    /// - Throws: An error if deleting the container fails.
    public func delete() async throws {
        try await container.delete()
    }
}

// MARK: - MongoDB Container Module

/// A container for MongoDB with pre-configured settings.
public class MongoDbContainer {
    private let builder: ContainerBuilder
    private var initdbRootUsername: String = "admin"
    private var initdbRootPassword: String = "admin"
    private var port: Int = 27017
    private var version: String = "latest"

    /// Initializes a new MongoDB container.
    /// - Parameter version: The MongoDB version, defaults to "latest".
    public init(version: String = "latest") {
        self.version = version
        let imageName = "mongo:\(version)"
        self.builder = ContainerBuilder(imageName)
            .withName("mongo-\(UUID().uuidString)")
            .withPortBinding(port, assignRandomHostPort: true)
            .withEnvironment("MONGO_INITDB_ROOT_USERNAME", "admin")
            .withEnvironment("MONGO_INITDB_ROOT_PASSWORD", "admin")
    }

    /// Sets the username.
    /// - Parameter username: The username.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withUsername(_ username: String) -> MongoDbContainer {
        initdbRootUsername = username
        builder.withEnvironment("MONGO_INITDB_ROOT_USERNAME", username)
        return self
    }

    /// Sets the password.
    /// - Parameter password: The password.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withPassword(_ password: String) -> MongoDbContainer {
        initdbRootPassword = password
        builder.withEnvironment("MONGO_INITDB_ROOT_PASSWORD", password)
        return self
    }

    /// Starts the MongoDB container.
    /// - Returns: A reference to the started container.
    /// - Throws: An error if starting the container fails.
    public func start() async throws -> MongoDbContainerReference {
        let container = try await builder
            .withWaitStrategy(
                Wait.http(port: port, timeout: 60)
            )
            .buildAsync()

        try await container.start()

        return MongoDbContainerReference(
            container: container,
            username: initdbRootUsername,
            password: initdbRootPassword,
            port: port
        )
    }
}

/// A reference to a running MongoDB container.
public class MongoDbContainerReference: @unchecked Sendable {
    /// The underlying container.
    public let container: Container
    /// The username.
    public let username: String
    /// The password.
    public let password: String
    /// The port number.
    public let port: Int

    /// Initializes a new MongoDB container reference.
    /// - Parameters:
    ///   - container: The container.
    ///   - username: The username.
    ///   - password: The password.
    ///   - port: The port number.
    init(
        container: Container,
        username: String,
        password: String,
        port: Int)
    {
        self.container = container
        self.username = username
        self.password = password
        self.port = port
    }

    /// Gets the MongoDB connection string.
    /// - Returns: The connection string.
    /// - Throws: An error if the port mapping is not found.
    public func getConnectionString() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(port)
        return "mongodb://\(username):\(password)@\(host):\(mappedPort)/"
    }

    /// Stops the container.
    /// - Throws: An error if stopping the container fails.
    public func stop() async throws {
        try await container.stop(timeout: 10)
    }

    /// Deletes the container.
    /// - Throws: An error if deleting the container fails.
    public func delete() async throws {
        try await container.delete()
    }
}
