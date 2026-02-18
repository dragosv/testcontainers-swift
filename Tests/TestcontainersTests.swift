import Testcontainers
import XCTest

final class ContainerTests: XCTestCase {
    var postgres: PostgresContainerReference?

    override func setUp() async throws {
        try await super.setUp()
        postgres = try await PostgresContainer(version: "15")
            .withDatabase("testdb")
            .withUsername("testuser")
            .withPassword("testpass")
            .start()
    }

    override func tearDown() async throws {
        if let postgres {
            try await postgres.stop()
        }
        try await super.tearDown()
    }

    func testPostgresConnectionString() throws {
        let connectionString = try postgres?.getConnectionString()
        XCTAssertNotNil(connectionString)
        XCTAssert(connectionString?.contains("postgresql://") ?? false)
        XCTAssert(connectionString?.contains("testdb") ?? false)
    }
}

final class NetworkTests: XCTestCase {
    func testCreateNetwork() async throws {
        let networkName = "test-network-\(UUID().uuidString)"
        let network = try await NetworkBuilder(networkName)
            .withDriver("bridge")
            .build()

        XCTAssertNotNil(network.id)
        XCTAssertEqual(network.name, networkName)
        XCTAssertEqual(network.driver, "bridge")

        try? await DockerClient.getInstance().removeNetwork(id: network.id)
    }

    func testMultipleContainersOnNetwork() async throws {
        let networkName = "app-network-\(UUID().uuidString)"
        let network = try await NetworkBuilder(networkName)
            .build()

        let postgres = try await ContainerBuilder("postgres:15")
            .withName("postgres-\(UUID().uuidString)")
            .withEnvironment("POSTGRES_PASSWORD", "password")
            .withNetwork(network)
            .buildAsync()

        let app = try await ContainerBuilder("alpine:latest")
            .withName("app-\(UUID().uuidString)")
            .withNetwork(network)
            .buildAsync()

        // Containers are created and associated with network
        XCTAssertNotNil(postgres.id)
        XCTAssertNotNil(app.id)

        // Cleanup
        try? await postgres.stop(timeout: 10)
        try? await postgres.delete()
        try? await app.stop(timeout: 10) // Alpine might exit immediately, but safe to call stop
        try? await app.delete()
        try? await DockerClient.getInstance().removeNetwork(id: network.id)
    }
}

final class ContainerBuilderTests: XCTestCase {
    func testBuilderFluentAPI() {
        let builder = ContainerBuilder("nginx:latest")
            .withName("test-nginx")
            .withPortBinding(80, assignRandomHostPort: true)
            .withEnvironment("NGINX_PORT", "80")
            .withLabel("env", "test")
            .withLabel("component", "web")

        let container = builder.build()
        XCTAssertEqual(container.image, "nginx:latest")
    }
}

final class WaitStrategyTests: XCTestCase {
    func testWaitStrategyCreation() {
        let httpWait = Wait.http(port: 8080, path: "/health")
        XCTAssert(httpWait is HttpWaitStrategy)

        let tcpWait = Wait.tcp(port: 3306)
        XCTAssert(tcpWait is TcpWaitStrategy)

        let logWait = Wait.log(message: "Server started")
        XCTAssert(logWait is LogWaitStrategy)

        let combined = Wait.all(
            Wait.tcp(port: 3306),
            Wait.http(port: 8080)
        )
        XCTAssert(combined is CombinedWaitStrategy)
    }
}

final class IntegrationTests: XCTestCase {
    func testFullLifecycle() async throws {
        // Create container
        let container = try await ContainerBuilder("alpine:latest")
            .withCmd(["sh", "-c", "echo 'Hello' && sleep 30"])
            .buildAsync()

        // Start container
        try await container.start()

        // Verify container is running
        let state = try await container.getState()
        // State should be running or exited depending on timing
        XCTAssertNotNil(state)

        // Stop container
        try await container.stop(timeout: 10)
    }
}

// MARK: - Module Tests

final class PostgresModuleTests: XCTestCase {
    func testPostgresContainer() async throws {
        let postgres = try await PostgresContainer(version: "15")
            .withDatabase("mydb")
            .withUsername("myuser")
            .withPassword("mypass")
            .start()

        defer { Task { @MainActor in try? await postgres.stop() } }

        let connectionString = try postgres.getConnectionString()
        XCTAssert(connectionString.contains("postgresql://"))
        XCTAssert(connectionString.contains("myuser:mypass"))
        XCTAssert(connectionString.contains("mydb"))
    }
}

final class MySqlModuleTests: XCTestCase {
    func testMySqlContainer() async throws {
        let mysql = try await MySqlContainer(version: "8.0")
            .withDatabase("testdb")
            .withUsername("root")
            .withPassword("rootpass")
            .start()

        defer { Task { @MainActor in try? await mysql.stop() } }

        let connectionString = try mysql.getConnectionString()
        XCTAssert(connectionString.contains("mysql://"))
        XCTAssert(connectionString.contains("testdb"))
    }
}

final class RedisModuleTests: XCTestCase {
    func testRedisContainer() async throws {
        let redis = try await RedisContainer(version: "7")
            .start()

        defer { Task { @MainActor in try? await redis.stop() } }

        let redisURL = try redis.getRedisURL()
        XCTAssert(redisURL.contains("redis://"))
    }
}

final class MongoDbModuleTests: XCTestCase {
    func testMongoDbContainer() async throws {
        let mongo = try await MongoDbContainer(version: "6.0")
            .withUsername("admin")
            .withPassword("password")
            .start()

        defer { Task { @MainActor in try? await mongo.stop() } }

        let connectionString = try mongo.getConnectionString()
        XCTAssert(connectionString.contains("mongodb://"))
        XCTAssert(connectionString.contains("admin:password"))
    }
}
