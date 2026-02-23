import Foundation
import Testcontainers

// MARK: - Example 1: Basic Container Usage

@main
func exampleBasicContainer() async throws {
    print("=== Example 1: Basic Container Usage ===")

    let container = ContainerBuilder("nginx:latest")
        .withName("my-nginx")
        .withPortBinding(80, assignRandomHostPort: true)
        .withLabel("env", "example")
        .build()

    let actualContainer = try await ContainerBuilder("nginx:latest")
        .withPortBinding(80, assignRandomHostPort: true)
        .withWaitStrategy(.tcp(port: 80, timeout: 30))
        .buildAsync()

    try await actualContainer.start()

    let port = try actualContainer.getMappedPort(80)
    print("Nginx container started on port: \(port)")

    let state = try await actualContainer.getState()
    print("Container state: \(state)")

    try await actualContainer.stop()
    print("Container stopped\n")
}

// MARK: - Example 2: PostgreSQL Database

func examplePostgresql() async throws {
    print("=== Example 2: PostgreSQL Container ===")

    let postgres = try await PostgresContainer(version: "15")
        .withDatabase("testdb")
        .withUsername("testuser")
        .withPassword("testpass")
        .start()

    defer { try? Task { try await postgres.stop() }.value }

    let connectionString = try postgres.getConnectionString()
    print("PostgreSQL is running at: \(connectionString)")
    print()
}

// MARK: - Example 3: MySQL Database

func exampleMysql() async throws {
    print("=== Example 3: MySQL Container ===")

    let mysql = try await MySqlContainer(version: "8.0")
        .withDatabase("testdb")
        .withUsername("testuser")
        .withPassword("testpass")
        .start()

    defer { try? Task { try await mysql.stop() }.value }

    let connectionString = try mysql.getConnectionString()
    print("MySQL is running at: \(connectionString)")
    print()
}

// MARK: - Example 4: Redis

func exampleRedis() async throws {
    print("=== Example 4: Redis Container ===")

    let redis = try await RedisContainer(version: "7")
        .start()

    defer { try? Task { try await redis.stop() }.value }

    let redisURL = try redis.getRedisURL()
    print("Redis is running at: \(redisURL)")
    print()
}

// MARK: - Example 5: MongoDB

func exampleMongoDB() async throws {
    print("=== Example 5: MongoDB Container ===")

    let mongo = try await MongoDbContainer(version: "6.0")
        .withUsername("admin")
        .withPassword("admin")
        .start()

    defer { try? Task { try await mongo.stop() }.value }

    let connectionString = try mongo.getConnectionString()
    print("MongoDB is running at: \(connectionString)")
    print()
}

// MARK: - Example 6: Multiple Containers with Network

func exampleMultipleContainersWithNetwork() async throws {
    print("=== Example 6: Multiple Containers with Network ===")

    // Create a custom network
    let network = try await NetworkBuilder("test-network")
        .withDriver("bridge")
        .build()

    // Create PostgreSQL container
    let postgres = try await ContainerBuilder("postgres:15")
        .withName("postgres-service")
        .withEnvironment("POSTGRES_PASSWORD", "password")
        .withWaitStrategy(.log(message: "database system is ready"))
        .withNetwork(network)
        .withNetworkAliases(["postgres"])
        .buildAsync()

    try await postgres.start()

    print("PostgreSQL started on network")
    print("Other containers can reach it using hostname: postgres")

    try await postgres.stop()
    print("PostgreSQL stopped\n")
}

// MARK: - Example 7: Microsoft SQL Server

func exampleMsSql() async throws {
    print("=== Example 7: Microsoft SQL Server Container ===")

    let mssql = try await MsSqlContainer()
        .withDatabase("testdb")
        .withPassword("yourStrong(!)Password")
        .start()

    defer { try? Task { try await mssql.stop() }.value }

    let connectionString = try mssql.getConnectionString()
    print("MS SQL Server is running at: \(connectionString)")
    print()
}

// MARK: - Example 8: RabbitMQ

func exampleRabbitMq() async throws {
    print("=== Example 8: RabbitMQ Container ===")

    let rabbitmq = try await RabbitMqContainer(version: "3.11")
        .withUsername("guest")
        .withPassword("guest")
        .start()

    defer { try? Task { try await rabbitmq.stop() }.value }

    let connectionString = try rabbitmq.getConnectionString()
    print("RabbitMQ is running at: \(connectionString)")
    print()
}

// MARK: - Example 9: Kafka

func exampleKafka() async throws {
    print("=== Example 9: Kafka Container ===")

    let kafka = try await KafkaContainer()
        .start()

    defer { try? Task { try await kafka.stop() }.value }

    let bootstrapServers = kafka.getBootstrapServers()
    print("Kafka bootstrap servers: \(bootstrapServers)")
    print()
}

// MARK: - Example 10: Elasticsearch

func exampleElasticsearch() async throws {
    print("=== Example 10: Elasticsearch Container ===")

    let elasticsearch = try await ElasticsearchContainer(version: "8.6.1")
        .withPassword("elastic")
        .start()

    defer { try? Task { try await elasticsearch.stop() }.value }

    let connectionString = try elasticsearch.getConnectionString()
    print("Elasticsearch is running at: \(connectionString)")
    print()
}

// MARK: - Example 11: Azurite (Azure Storage Emulator)

func exampleAzurite() async throws {
    print("=== Example 11: Azurite Container ===")

    let azurite = try await AzuriteContainer()
        .start()

    defer { try? Task { try await azurite.stop() }.value }

    let connectionString = try azurite.getConnectionString()
    print("Azurite connection string: \(connectionString)")

    let blobEndpoint = try azurite.getBlobEndpoint()
    print("Blob endpoint: \(blobEndpoint)")
    print()
}

// MARK: - Example 12: LocalStack (AWS Emulator)

func exampleLocalStack() async throws {
    print("=== Example 12: LocalStack Container ===")

    let localstack = try await LocalStackContainer()
        .start()

    defer { try? Task { try await localstack.stop() }.value }

    let endpoint = try localstack.getEndpoint()
    print("LocalStack endpoint: \(endpoint)")
    print()
}

// MARK: - Example 13: Wait Strategies

func exampleWaitStrategies() async throws {
    print("=== Example 13: Wait Strategies ===")

    // HTTP wait strategy
    let webContainer = try await ContainerBuilder("httpbin/httpbin:latest")
        .withPortBinding(80, assignRandomHostPort: true)
        .withWaitStrategy(.http(port: 80, path: "/uuid", timeout: 60))
        .buildAsync()

    try await webContainer.start()
    print("HTTP container is ready")
    try await webContainer.stop()

    // Combined wait strategies
    let dbContainer = try await ContainerBuilder("postgres:15")
        .withEnvironment("POSTGRES_PASSWORD", "password")
        .withPortBinding(5432, assignRandomHostPort: true)
        .withWaitStrategy(
            .all(
                .tcp(port: 5432, timeout: 60),
                .log(message: "database system is ready", timeout: 60)
            )
        )
        .buildAsync()

    try await dbContainer.start()
    print("Database container is ready (used combined wait strategies)")
    try await dbContainer.stop()
    print()
}

// MARK: - Example 14: Container Logs

func exampleContainerLogs() async throws {
    print("=== Example 14: Container Logs ===")

    let container = try await ContainerBuilder("alpine:latest")
        .withCmd(["sh", "-c", "echo 'Hello from container' && sleep 10"])
        .buildAsync()

    try await container.start()

    try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds

    let logs = try await container.getLogs()
    print("Container logs:")
    print(logs)

    try await container.stop()
    print()
}

// MARK: - Main

@main
struct ExamplesApp {
    static func main() async {
        print("Testcontainers Swift Examples\n")

        do {
            // Uncomment examples to run them

            // try await exampleBasicContainer()
            // try await examplePostgresql()
            // try await exampleMysql()
            // try await exampleRedis()
            // try await exampleMongoDB()
            // try await exampleMultipleContainersWithNetwork()
            // try await exampleMsSql()
            // try await exampleRabbitMq()
            // try await exampleKafka()
            // try await exampleElasticsearch()
            // try await exampleAzurite()
            // try await exampleLocalStack()
            // try await exampleWaitStrategies()
            // try await exampleContainerLogs()

            print("Examples completed successfully!")
        } catch {
            print("Error: \(error)")
        }
    }
}
