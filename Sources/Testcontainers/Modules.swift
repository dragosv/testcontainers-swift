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

    /// Gets the Redis connection string (alias for `getRedisURL()`).
    /// - Returns: The connection string.
    /// - Throws: An error if the port mapping is not found.
    public func getConnectionString() throws -> String {
        try getRedisURL()
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

// MARK: - Microsoft SQL Server Container Module

/// A container for Microsoft SQL Server with pre-configured settings.
public class MsSqlContainer {
    private let builder: ContainerBuilder
    private var database: String = "master"
    private var username: String = "sa"
    private var password: String = "yourStrong(!)Password"
    private var port: Int = 1433
    private var version: String = "2022-CU14-ubuntu-22.04"

    /// Initializes a new Microsoft SQL Server container.
    /// - Parameter version: The SQL Server version tag, defaults to "2022-CU14-ubuntu-22.04".
    public init(version: String = "2022-CU14-ubuntu-22.04") {
        self.version = version
        let imageName = "mcr.microsoft.com/mssql/server:\(version)"
        self.builder = ContainerBuilder(imageName)
            .withName("mssql-\(UUID().uuidString)")
            .withPortBinding(port, assignRandomHostPort: true)
            .withEnvironment("ACCEPT_EULA", "Y")
            .withEnvironment("MSSQL_SA_PASSWORD", password)
    }

    /// Sets the database name.
    /// - Parameter database: The database name.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withDatabase(_ database: String) -> MsSqlContainer {
        self.database = database
        return self
    }

    /// Sets the SA password.
    /// - Parameter password: The password.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withPassword(_ password: String) -> MsSqlContainer {
        self.password = password
        builder.withEnvironment("MSSQL_SA_PASSWORD", password)
        return self
    }

    /// Starts the Microsoft SQL Server container.
    /// - Returns: A reference to the started container.
    /// - Throws: An error if starting the container fails.
    public func start() async throws -> MsSqlContainerReference {
        let container = try await builder
            .withWaitStrategy(
                Wait.all(
                    Wait.tcp(port: port),
                    Wait.exec(
                        command: [
                            "/opt/mssql-tools/bin/sqlcmd",
                            "-C", "-Q", "SELECT 1;",
                        ],
                        timeout: 60
                    )
                )
            )
            .buildAsync()

        try await container.start()

        return MsSqlContainerReference(
            container: container,
            database: database,
            username: username,
            password: password,
            port: port
        )
    }
}

/// A reference to a running Microsoft SQL Server container.
public class MsSqlContainerReference: @unchecked Sendable {
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

    /// Initializes a new Microsoft SQL Server container reference.
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

    /// Gets the Microsoft SQL Server connection string.
    /// - Returns: The connection string.
    /// - Throws: An error if the port mapping is not found.
    public func getConnectionString() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(port)
        return "Server=\(host),\(mappedPort);Database=\(database);User Id=\(username);Password=\(password);TrustServerCertificate=True"
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

// MARK: - RabbitMQ Container Module

/// A container for RabbitMQ message broker with pre-configured settings.
public class RabbitMqContainer {
    private let builder: ContainerBuilder
    private var username: String = "rabbitmq"
    private var password: String = "rabbitmq"
    private var port: Int = 5672
    private var version: String = "3.11"

    /// Initializes a new RabbitMQ container.
    /// - Parameter version: The RabbitMQ version, defaults to "3.11".
    public init(version: String = "3.11") {
        self.version = version
        let imageName = "rabbitmq:\(version)"
        self.builder = ContainerBuilder(imageName)
            .withName("rabbitmq-\(UUID().uuidString)")
            .withPortBinding(port, assignRandomHostPort: true)
            .withEnvironment("RABBITMQ_DEFAULT_USER", username)
            .withEnvironment("RABBITMQ_DEFAULT_PASS", password)
    }

    /// Sets the username.
    /// - Parameter username: The username.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withUsername(_ username: String) -> RabbitMqContainer {
        self.username = username
        builder.withEnvironment("RABBITMQ_DEFAULT_USER", username)
        return self
    }

    /// Sets the password.
    /// - Parameter password: The password.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withPassword(_ password: String) -> RabbitMqContainer {
        self.password = password
        builder.withEnvironment("RABBITMQ_DEFAULT_PASS", password)
        return self
    }

    /// Starts the RabbitMQ container.
    /// - Returns: A reference to the started container.
    /// - Throws: An error if starting the container fails.
    public func start() async throws -> RabbitMqContainerReference {
        let container = try await builder
            .withWaitStrategy(
                Wait.all(
                    Wait.tcp(port: port),
                    Wait.log(message: "Server startup complete", timeout: 60)
                )
            )
            .buildAsync()

        try await container.start()

        return RabbitMqContainerReference(
            container: container,
            username: username,
            password: password,
            port: port
        )
    }
}

/// A reference to a running RabbitMQ container.
public class RabbitMqContainerReference: @unchecked Sendable {
    /// The underlying container.
    public let container: Container
    /// The username.
    public let username: String
    /// The password.
    public let password: String
    /// The port number.
    public let port: Int

    /// Initializes a new RabbitMQ container reference.
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

    /// Gets the RabbitMQ AMQP connection string.
    /// - Returns: The connection string.
    /// - Throws: An error if the port mapping is not found.
    public func getConnectionString() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(port)
        return "amqp://\(username):\(password)@\(host):\(mappedPort)/"
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

// MARK: - Kafka Container Module

/// A container for Apache Kafka with pre-configured settings using KRaft mode.
public class KafkaContainer {
    private let builder: ContainerBuilder
    private var port: Int = 9092
    private var version: String = "7.5.12"

    /// Initializes a new Kafka container (Confluent Platform).
    /// - Parameter version: The Confluent Platform version, defaults to "7.5.12".
    public init(version: String = "7.5.12") {
        self.version = version
        let imageName = "confluentinc/cp-kafka:\(version)"
        self.builder = ContainerBuilder(imageName)
            .withName("kafka-\(UUID().uuidString)")
            .withPortBinding(port, assignRandomHostPort: true)
            .withEnvironment("KAFKA_LISTENERS", "PLAINTEXT://:9092,BROKER://:9093,CONTROLLER://:9094")
            .withEnvironment(
                "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP",
                "BROKER:PLAINTEXT,CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"
            )
            .withEnvironment("KAFKA_INTER_BROKER_LISTENER_NAME", "BROKER")
            .withEnvironment("KAFKA_BROKER_ID", "1")
            .withEnvironment("KAFKA_NODE_ID", "1")
            .withEnvironment("KAFKA_CONTROLLER_QUORUM_VOTERS", "1@localhost:9094")
            .withEnvironment("KAFKA_CONTROLLER_LISTENER_NAMES", "CONTROLLER")
            .withEnvironment("KAFKA_PROCESS_ROLES", "broker,controller")
            .withEnvironment("KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR", "1")
            .withEnvironment("KAFKA_OFFSETS_TOPIC_NUM_PARTITIONS", "1")
            .withEnvironment("KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR", "1")
            .withEnvironment("KAFKA_TRANSACTION_STATE_LOG_MIN_ISR", "1")
            .withEnvironment("KAFKA_LOG_FLUSH_INTERVAL_MESSAGES", "9223372036854775807")
            .withEnvironment("KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS", "0")
            .withEnvironment("CLUSTER_ID", "4L6g3nShT-eMCtK--X86sw")
            .withEnvironment("KAFKA_ADVERTISED_LISTENERS", "PLAINTEXT://localhost:9092,BROKER://localhost:9093")
    }

    /// Starts the Kafka container.
    /// - Returns: A reference to the started container.
    /// - Throws: An error if starting the container fails.
    public func start() async throws -> KafkaContainerReference {
        let container = try await builder
            .withWaitStrategy(
                Wait.log(message: "Transitioning from RECOVERY to RUNNING", timeout: 60)
            )
            .buildAsync()

        try await container.start()

        // Update advertised listeners with actual mapped port
        let mappedPort = try container.getMappedPort(port)
        let host = container.host ?? "localhost"

        return KafkaContainerReference(
            container: container,
            host: host,
            port: port,
            mappedPort: mappedPort
        )
    }
}

/// A reference to a running Kafka container.
public class KafkaContainerReference: @unchecked Sendable {
    /// The underlying container.
    public let container: Container
    /// The host where Kafka is running.
    public let host: String
    /// The container port number.
    public let port: Int
    /// The mapped host port number.
    public let mappedPort: Int

    /// Initializes a new Kafka container reference.
    /// - Parameters:
    ///   - container: The container.
    ///   - host: The host.
    ///   - port: The container port.
    ///   - mappedPort: The mapped host port.
    init(
        container: Container,
        host: String,
        port: Int,
        mappedPort: Int)
    {
        self.container = container
        self.host = host
        self.port = port
        self.mappedPort = mappedPort
    }

    /// Gets the Kafka bootstrap servers address.
    /// - Returns: The bootstrap servers address (host:port).
    public func getBootstrapServers() -> String {
        "\(host):\(mappedPort)"
    }

    /// Gets the Kafka connection string (bootstrap servers).
    /// - Returns: The connection string.
    public func getConnectionString() -> String {
        getBootstrapServers()
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

// MARK: - Elasticsearch Container Module

/// A container for Elasticsearch with pre-configured settings.
public class ElasticsearchContainer {
    private let builder: ContainerBuilder
    private var username: String = "elastic"
    private var password: String = "elastic"
    private var port: Int = 9200
    private var version: String = "8.6.1"

    /// Initializes a new Elasticsearch container.
    /// - Parameter version: The Elasticsearch version, defaults to "8.6.1".
    public init(version: String = "8.6.1") {
        self.version = version
        let imageName = "elasticsearch:\(version)"
        self.builder = ContainerBuilder(imageName)
            .withName("elasticsearch-\(UUID().uuidString)")
            .withPortBinding(port, assignRandomHostPort: true)
            .withEnvironment("ELASTIC_PASSWORD", password)
            .withEnvironment("discovery.type", "single-node")
            .withEnvironment("ingest.geoip.downloader.enabled", "false")
            .withEnvironment("xpack.security.enabled", "false")
    }

    /// Sets the password.
    /// - Parameter password: The password.
    /// - Returns: The container instance for chaining.
    @discardableResult
    public func withPassword(_ password: String) -> ElasticsearchContainer {
        self.password = password
        builder.withEnvironment("ELASTIC_PASSWORD", password)
        return self
    }

    /// Starts the Elasticsearch container.
    /// - Returns: A reference to the started container.
    /// - Throws: An error if starting the container fails.
    public func start() async throws -> ElasticsearchContainerReference {
        let container = try await builder
            .withWaitStrategy(
                Wait.all(
                    Wait.tcp(port: port),
                    Wait.http(port: port, path: "/_cluster/health", timeout: 120)
                )
            )
            .buildAsync()

        try await container.start()

        return ElasticsearchContainerReference(
            container: container,
            username: username,
            password: password,
            port: port
        )
    }
}

/// A reference to a running Elasticsearch container.
public class ElasticsearchContainerReference: @unchecked Sendable {
    /// The underlying container.
    public let container: Container
    /// The username.
    public let username: String
    /// The password.
    public let password: String
    /// The port number.
    public let port: Int

    /// Initializes a new Elasticsearch container reference.
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

    /// Gets the Elasticsearch HTTP URL.
    /// - Returns: The connection string.
    /// - Throws: An error if the port mapping is not found.
    public func getConnectionString() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(port)
        return "http://\(username):\(password)@\(host):\(mappedPort)/"
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

// MARK: - Azurite Container Module

/// A container for Azurite (Azure Storage Emulator) with pre-configured settings.
public class AzuriteContainer {
    private let builder: ContainerBuilder
    private var blobPort: Int = 10000
    private var queuePort: Int = 10001
    private var tablePort: Int = 10002
    private var version: String = "3.28.0"
    /// The well-known Azurite account name.
    public static let accountName = "devstoreaccount1"
    /// The well-known Azurite account key.
    public static let accountKey =
        "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="

    /// Initializes a new Azurite container.
    /// - Parameter version: The Azurite version, defaults to "3.28.0".
    public init(version: String = "3.28.0") {
        self.version = version
        let imageName = "mcr.microsoft.com/azure-storage/azurite:\(version)"
        self.builder = ContainerBuilder(imageName)
            .withName("azurite-\(UUID().uuidString)")
            .withPortBinding(blobPort, assignRandomHostPort: true)
            .withPortBinding(queuePort, assignRandomHostPort: true)
            .withPortBinding(tablePort, assignRandomHostPort: true)
    }

    /// Starts the Azurite container.
    /// - Returns: A reference to the started container.
    /// - Throws: An error if starting the container fails.
    public func start() async throws -> AzuriteContainerReference {
        let container = try await builder
            .withWaitStrategy(
                Wait.all(
                    Wait.log(message: "Blob service is successfully listening", timeout: 60),
                    Wait.log(message: "Queue service is successfully listening", timeout: 60),
                    Wait.log(message: "Table service is successfully listening", timeout: 60)
                )
            )
            .buildAsync()

        try await container.start()

        return AzuriteContainerReference(
            container: container,
            blobPort: blobPort,
            queuePort: queuePort,
            tablePort: tablePort
        )
    }
}

/// A reference to a running Azurite container.
public class AzuriteContainerReference: @unchecked Sendable {
    /// The underlying container.
    public let container: Container
    /// The Blob service port number.
    public let blobPort: Int
    /// The Queue service port number.
    public let queuePort: Int
    /// The Table service port number.
    public let tablePort: Int

    /// Initializes a new Azurite container reference.
    /// - Parameters:
    ///   - container: The container.
    ///   - blobPort: The Blob service port.
    ///   - queuePort: The Queue service port.
    ///   - tablePort: The Table service port.
    init(
        container: Container,
        blobPort: Int,
        queuePort: Int,
        tablePort: Int)
    {
        self.container = container
        self.blobPort = blobPort
        self.queuePort = queuePort
        self.tablePort = tablePort
    }

    /// Gets the Azurite connection string for all services.
    /// - Returns: The connection string.
    /// - Throws: An error if the port mappings are not found.
    public func getConnectionString() throws -> String {
        let host = container.host ?? "localhost"
        let mappedBlobPort = try container.getMappedPort(blobPort)
        let mappedQueuePort = try container.getMappedPort(queuePort)
        let mappedTablePort = try container.getMappedPort(tablePort)
        let accountName = AzuriteContainer.accountName
        let accountKey = AzuriteContainer.accountKey
        return "DefaultEndpointsProtocol=http;"
            + "AccountName=\(accountName);"
            + "AccountKey=\(accountKey);"
            + "BlobEndpoint=http://\(host):\(mappedBlobPort)/\(accountName);"
            + "QueueEndpoint=http://\(host):\(mappedQueuePort)/\(accountName);"
            + "TableEndpoint=http://\(host):\(mappedTablePort)/\(accountName)"
    }

    /// Gets the Blob service endpoint URL.
    /// - Returns: The Blob service URL.
    /// - Throws: An error if the port mapping is not found.
    public func getBlobEndpoint() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(blobPort)
        return "http://\(host):\(mappedPort)/\(AzuriteContainer.accountName)"
    }

    /// Gets the Queue service endpoint URL.
    /// - Returns: The Queue service URL.
    /// - Throws: An error if the port mapping is not found.
    public func getQueueEndpoint() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(queuePort)
        return "http://\(host):\(mappedPort)/\(AzuriteContainer.accountName)"
    }

    /// Gets the Table service endpoint URL.
    /// - Returns: The Table service URL.
    /// - Throws: An error if the port mapping is not found.
    public func getTableEndpoint() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(tablePort)
        return "http://\(host):\(mappedPort)/\(AzuriteContainer.accountName)"
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

// MARK: - LocalStack Container Module

/// A container for LocalStack (AWS cloud emulator) with pre-configured settings.
public class LocalStackContainer {
    private let builder: ContainerBuilder
    private var port: Int = 4566
    private var version: String = "2.0"

    /// Initializes a new LocalStack container.
    /// - Parameter version: The LocalStack version, defaults to "2.0".
    public init(version: String = "2.0") {
        self.version = version
        let imageName = "localstack/localstack:\(version)"
        self.builder = ContainerBuilder(imageName)
            .withName("localstack-\(UUID().uuidString)")
            .withPortBinding(port, assignRandomHostPort: true)
    }

    /// Starts the LocalStack container.
    /// - Returns: A reference to the started container.
    /// - Throws: An error if starting the container fails.
    public func start() async throws -> LocalStackContainerReference {
        let container = try await builder
            .withWaitStrategy(
                Wait.http(port: port, path: "/_localstack/health", timeout: 60)
            )
            .buildAsync()

        try await container.start()

        return LocalStackContainerReference(
            container: container,
            port: port
        )
    }
}

/// A reference to a running LocalStack container.
public class LocalStackContainerReference: @unchecked Sendable {
    /// The underlying container.
    public let container: Container
    /// The port number.
    public let port: Int

    /// Initializes a new LocalStack container reference.
    /// - Parameters:
    ///   - container: The container.
    ///   - port: The port number.
    init(container: Container, port: Int) {
        self.container = container
        self.port = port
    }

    /// Gets the LocalStack endpoint URL.
    /// - Returns: The endpoint URL.
    /// - Throws: An error if the port mapping is not found.
    public func getConnectionString() throws -> String {
        try getEndpoint()
    }

    /// Gets the LocalStack endpoint URL.
    /// - Returns: The endpoint URL.
    /// - Throws: An error if the port mapping is not found.
    public func getEndpoint() throws -> String {
        let host = container.host ?? "localhost"
        let mappedPort = try container.getMappedPort(port)
        return "http://\(host):\(mappedPort)/"
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
