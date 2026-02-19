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

// MARK: - Wait Strategy Unit Tests

final class WaitStrategyUnitTests: XCTestCase {
    // MARK: - NoWaitStrategy Tests

    func testNoWaitStrategyInitialization() {
        let strategy = NoWaitStrategy()
        XCTAssertNotNil(strategy)
    }

    // MARK: - HttpWaitStrategy Tests

    func testHttpWaitStrategyDefaultValues() {
        let strategy = HttpWaitStrategy(port: 8080)
        XCTAssertEqual(strategy.port, 8080)
        XCTAssertEqual(strategy.path, "/")
        XCTAssertEqual(strategy.scheme, "http")
        XCTAssertEqual(strategy.timeout, 60)
        XCTAssertEqual(strategy.retries, 5)
    }

    func testHttpWaitStrategyCustomValues() {
        let strategy = HttpWaitStrategy(
            port: 3000,
            path: "/health",
            scheme: "https",
            timeout: 120,
            retries: 10
        )
        XCTAssertEqual(strategy.port, 3000)
        XCTAssertEqual(strategy.path, "/health")
        XCTAssertEqual(strategy.scheme, "https")
        XCTAssertEqual(strategy.timeout, 120)
        XCTAssertEqual(strategy.retries, 10)
    }

    // MARK: - TcpWaitStrategy Tests

    func testTcpWaitStrategyDefaultValues() {
        let strategy = TcpWaitStrategy(port: 5432)
        XCTAssertEqual(strategy.port, 5432)
        XCTAssertEqual(strategy.timeout, 60)
        XCTAssertEqual(strategy.retries, 5)
    }

    func testTcpWaitStrategyCustomValues() {
        let strategy = TcpWaitStrategy(port: 27017, timeout: 90, retries: 15)
        XCTAssertEqual(strategy.port, 27017)
        XCTAssertEqual(strategy.timeout, 90)
        XCTAssertEqual(strategy.retries, 15)
    }

    // MARK: - LogWaitStrategy Tests

    func testLogWaitStrategyDefaultTimeout() {
        let strategy = LogWaitStrategy(message: "Server started")
        XCTAssertEqual(strategy.message, "Server started")
        XCTAssertEqual(strategy.timeout, 60)
    }

    func testLogWaitStrategyCustomTimeout() {
        let strategy = LogWaitStrategy(message: "Ready to accept connections", timeout: 120)
        XCTAssertEqual(strategy.message, "Ready to accept connections")
        XCTAssertEqual(strategy.timeout, 120)
    }

    // MARK: - ExecWaitStrategy Tests

    func testExecWaitStrategyDefaultTimeout() {
        let strategy = ExecWaitStrategy(command: ["pg_isready", "-U", "postgres"])
        XCTAssertEqual(strategy.command, ["pg_isready", "-U", "postgres"])
        XCTAssertEqual(strategy.timeout, 60)
    }

    func testExecWaitStrategyCustomTimeout() {
        let strategy = ExecWaitStrategy(command: ["redis-cli", "ping"], timeout: 30)
        XCTAssertEqual(strategy.command, ["redis-cli", "ping"])
        XCTAssertEqual(strategy.timeout, 30)
    }

    // MARK: - HealthCheckWaitStrategy Tests

    func testHealthCheckWaitStrategyDefaultTimeout() {
        let strategy = HealthCheckWaitStrategy()
        XCTAssertEqual(strategy.timeout, 60)
    }

    func testHealthCheckWaitStrategyCustomTimeout() {
        let strategy = HealthCheckWaitStrategy(timeout: 180)
        XCTAssertEqual(strategy.timeout, 180)
    }

    // MARK: - CombinedWaitStrategy Tests

    func testCombinedWaitStrategyHoldsStrategies() {
        let tcp = TcpWaitStrategy(port: 5432)
        let http = HttpWaitStrategy(port: 8080, path: "/health")
        let combined = CombinedWaitStrategy([tcp, http])
        XCTAssertEqual(combined.strategies.count, 2)
    }

    func testCombinedWaitStrategyEmpty() {
        let combined = CombinedWaitStrategy([])
        XCTAssertEqual(combined.strategies.count, 0)
    }

    // MARK: - Wait Builder Tests

    func testWaitNoWait() {
        let strategy = Wait.noWait()
        XCTAssert(strategy is NoWaitStrategy)
    }

    func testWaitHttpWithDefaults() {
        let strategy = Wait.http(port: 8080)
        XCTAssert(strategy is HttpWaitStrategy)
        if let httpStrategy = strategy as? HttpWaitStrategy {
            XCTAssertEqual(httpStrategy.port, 8080)
            XCTAssertEqual(httpStrategy.path, "/")
            XCTAssertEqual(httpStrategy.scheme, "http")
            XCTAssertEqual(httpStrategy.timeout, 60)
        }
    }

    func testWaitHttpWithCustomValues() {
        let strategy = Wait.http(port: 3000, path: "/api/health", scheme: "https", timeout: 90)
        XCTAssert(strategy is HttpWaitStrategy)
        if let httpStrategy = strategy as? HttpWaitStrategy {
            XCTAssertEqual(httpStrategy.port, 3000)
            XCTAssertEqual(httpStrategy.path, "/api/health")
            XCTAssertEqual(httpStrategy.scheme, "https")
            XCTAssertEqual(httpStrategy.timeout, 90)
        }
    }

    func testWaitTcpWithDefaults() {
        let strategy = Wait.tcp(port: 5432)
        XCTAssert(strategy is TcpWaitStrategy)
        if let tcpStrategy = strategy as? TcpWaitStrategy {
            XCTAssertEqual(tcpStrategy.port, 5432)
            XCTAssertEqual(tcpStrategy.timeout, 60)
        }
    }

    func testWaitTcpWithCustomTimeout() {
        let strategy = Wait.tcp(port: 27017, timeout: 120)
        XCTAssert(strategy is TcpWaitStrategy)
        if let tcpStrategy = strategy as? TcpWaitStrategy {
            XCTAssertEqual(tcpStrategy.port, 27017)
            XCTAssertEqual(tcpStrategy.timeout, 120)
        }
    }

    func testWaitLogWithDefaults() {
        let strategy = Wait.log(message: "Database ready")
        XCTAssert(strategy is LogWaitStrategy)
        if let logStrategy = strategy as? LogWaitStrategy {
            XCTAssertEqual(logStrategy.message, "Database ready")
            XCTAssertEqual(logStrategy.timeout, 60)
        }
    }

    func testWaitLogWithCustomTimeout() {
        let strategy = Wait.log(message: "Accepting connections", timeout: 180)
        XCTAssert(strategy is LogWaitStrategy)
        if let logStrategy = strategy as? LogWaitStrategy {
            XCTAssertEqual(logStrategy.message, "Accepting connections")
            XCTAssertEqual(logStrategy.timeout, 180)
        }
    }

    func testWaitExecWithDefaults() {
        let strategy = Wait.exec(command: ["echo", "hello"])
        XCTAssert(strategy is ExecWaitStrategy)
        if let execStrategy = strategy as? ExecWaitStrategy {
            XCTAssertEqual(execStrategy.command, ["echo", "hello"])
            XCTAssertEqual(execStrategy.timeout, 60)
        }
    }

    func testWaitExecWithCustomTimeout() {
        let strategy = Wait.exec(command: ["pg_isready"], timeout: 45)
        XCTAssert(strategy is ExecWaitStrategy)
        if let execStrategy = strategy as? ExecWaitStrategy {
            XCTAssertEqual(execStrategy.command, ["pg_isready"])
            XCTAssertEqual(execStrategy.timeout, 45)
        }
    }

    func testWaitHealthCheckWithDefaults() {
        let strategy = Wait.healthCheck()
        XCTAssert(strategy is HealthCheckWaitStrategy)
        if let healthStrategy = strategy as? HealthCheckWaitStrategy {
            XCTAssertEqual(healthStrategy.timeout, 60)
        }
    }

    func testWaitHealthCheckWithCustomTimeout() {
        let strategy = Wait.healthCheck(timeout: 300)
        XCTAssert(strategy is HealthCheckWaitStrategy)
        if let healthStrategy = strategy as? HealthCheckWaitStrategy {
            XCTAssertEqual(healthStrategy.timeout, 300)
        }
    }

    func testWaitAllCombinesStrategies() {
        let strategy = Wait.all(
            Wait.tcp(port: 5432),
            Wait.log(message: "ready"),
            Wait.http(port: 8080)
        )
        XCTAssert(strategy is CombinedWaitStrategy)
        if let combinedStrategy = strategy as? CombinedWaitStrategy {
            XCTAssertEqual(combinedStrategy.strategies.count, 3)
        }
    }
}

// MARK: - Models Unit Tests

final class ModelsUnitTests: XCTestCase {
    // MARK: - ContainerStatus Tests

    func testContainerStatusRunning() {
        let status = ContainerStatus("running")
        XCTAssertEqual(status, .running)
    }

    func testContainerStatusRunningUppercase() {
        let status = ContainerStatus("RUNNING")
        XCTAssertEqual(status, .running)
    }

    func testContainerStatusExited() {
        let status = ContainerStatus("exited")
        XCTAssertEqual(status, .exited)
    }

    func testContainerStatusPaused() {
        let status = ContainerStatus("paused")
        XCTAssertEqual(status, .paused)
    }

    func testContainerStatusCreated() {
        let status = ContainerStatus("created")
        XCTAssertEqual(status, .created)
    }

    func testContainerStatusRestarting() {
        let status = ContainerStatus("restarting")
        XCTAssertEqual(status, .restarting)
    }

    func testContainerStatusDead() {
        let status = ContainerStatus("dead")
        XCTAssertEqual(status, .dead)
    }

    func testContainerStatusUnknown() {
        let status = ContainerStatus("something-else")
        XCTAssertEqual(status, .unknown)
    }

    func testContainerStatusEmptyString() {
        let status = ContainerStatus("")
        XCTAssertEqual(status, .unknown)
    }

    // MARK: - PortBinding Tests

    func testPortBindingDefaultProtocol() {
        let binding = PortBinding(containerPort: 8080, hostPort: 8080)
        XCTAssertEqual(binding.containerPort, 8080)
        XCTAssertEqual(binding.hostPort, 8080)
        XCTAssertEqual(binding.proto, "tcp")
    }

    func testPortBindingCustomProtocol() {
        let binding = PortBinding(containerPort: 53, hostPort: 5353, proto: "udp")
        XCTAssertEqual(binding.containerPort, 53)
        XCTAssertEqual(binding.hostPort, 5353)
        XCTAssertEqual(binding.proto, "udp")
    }

    // MARK: - PortBindingConfig Tests

    func testPortBindingConfigDefaultValues() {
        let config = PortBindingConfig()
        XCTAssertNil(config.hostIp)
        XCTAssertNil(config.hostPort)
    }

    func testPortBindingConfigWithValues() {
        let config = PortBindingConfig(hostIp: "0.0.0.0", hostPort: "8080")
        XCTAssertEqual(config.hostIp, "0.0.0.0")
        XCTAssertEqual(config.hostPort, "8080")
    }

    // MARK: - CreateContainerRequest Tests

    func testCreateContainerRequestDefaultValues() {
        let request = CreateContainerRequest(image: "nginx:latest")
        XCTAssertEqual(request.image, "nginx:latest")
        XCTAssertNil(request.hostname)
        XCTAssertNil(request.env)
        XCTAssertNil(request.cmd)
        XCTAssertNil(request.entrypoint)
        XCTAssertNil(request.exposedPorts)
        XCTAssertNil(request.labels)
        XCTAssertNil(request.portBindings)
        XCTAssertNil(request.networkMode)
    }

    func testCreateContainerRequestWithEnvironment() {
        var request = CreateContainerRequest(image: "postgres:15")
        request.env = ["POSTGRES_PASSWORD=secret", "POSTGRES_DB=test"]
        XCTAssertEqual(request.env?.count, 2)
    }

    // MARK: - ImagePullOptions Tests

    func testImagePullOptionsNilTag() {
        let options = ImagePullOptions()
        XCTAssertNil(options.tag)
    }

    func testImagePullOptionsWithTag() {
        let options = ImagePullOptions(tag: "latest")
        XCTAssertEqual(options.tag, "latest")
    }

    // MARK: - ExecResult Tests

    func testExecResultDefaultValues() {
        let result = ExecResult()
        XCTAssertNil(result.exitCode)
        XCTAssertNil(result.output)
    }

    func testExecResultWithValues() {
        let result = ExecResult(exitCode: 0, output: "Hello World")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.output, "Hello World")
    }

    // MARK: - TestcontainersConfiguration Tests

    func testTestcontainersConfigurationDefaultValues() {
        let config = TestcontainersConfiguration()
        XCTAssertNil(config.dockerEndpoint)
        XCTAssertNil(config.dockerHost)
        XCTAssertFalse(config.tlsVerify)
        XCTAssertNil(config.tlsCertPath)
    }

    func testTestcontainersConfigurationMutableProperties() {
        var config = TestcontainersConfiguration()
        config.dockerEndpoint = "unix:///var/run/docker.sock"
        config.dockerHost = "localhost"
        config.tlsVerify = true
        config.tlsCertPath = "/path/to/certs"

        XCTAssertEqual(config.dockerEndpoint, "unix:///var/run/docker.sock")
        XCTAssertEqual(config.dockerHost, "localhost")
        XCTAssertTrue(config.tlsVerify)
        XCTAssertEqual(config.tlsCertPath, "/path/to/certs")
    }
}

// MARK: - TestcontainersError Tests

final class TestcontainersErrorTests: XCTestCase {
    func testDockerNotAvailableError() {
        let error = TestcontainersError.dockerNotAvailable
        XCTAssertEqual(error.errorDescription, "Docker is not available")
    }

    func testInvalidImageError() {
        let error = TestcontainersError.invalidImage
        XCTAssertEqual(error.errorDescription, "Invalid Docker image")
    }

    func testContainerNotFoundError() {
        let error = TestcontainersError.containerNotFound("abc123")
        XCTAssertEqual(error.errorDescription, "Container not found: abc123")
    }

    func testContainerFailedError() {
        let error = TestcontainersError.containerFailed("Failed to start")
        XCTAssertEqual(error.errorDescription, "Container failed: Failed to start")
    }

    func testPortMappingFailedError() {
        let error = TestcontainersError.portMappingFailed(8080)
        XCTAssertEqual(error.errorDescription, "Port mapping failed for port 8080")
    }

    func testWaitStrategyFailedError() {
        let error = TestcontainersError.waitStrategyFailed("Timeout waiting for HTTP")
        XCTAssertEqual(error.errorDescription, "Wait strategy failed: Timeout waiting for HTTP")
    }

    func testNetworkErrorError() {
        let error = TestcontainersError.networkError("Network not found")
        XCTAssertEqual(error.errorDescription, "Network error: Network not found")
    }

    func testInvalidConfigurationError() {
        let error = TestcontainersError.invalidConfiguration("Missing image")
        XCTAssertEqual(error.errorDescription, "Invalid configuration: Missing image")
    }

    func testApiErrorError() {
        let error = TestcontainersError.apiError("500 Internal Server Error")
        XCTAssertEqual(error.errorDescription, "Docker API error: 500 Internal Server Error")
    }

    func testTimeoutError() {
        let error = TestcontainersError.timeout
        XCTAssertEqual(error.errorDescription, "Operation timed out")
    }
}

// MARK: - Container Builder Unit Tests

final class ContainerBuilderUnitTests: XCTestCase {
    func testBuilderWithName() {
        let builder = ContainerBuilder("alpine:latest")
            .withName("my-container")
        let container = builder.build()
        XCTAssertEqual(container.name, "my-container")
    }

    func testBuilderWithEnvironmentDictionary() {
        let builder = ContainerBuilder("postgres:15")
            .withEnvironment(["POSTGRES_PASSWORD": "secret", "POSTGRES_DB": "testdb"])
        let container = builder.build()
        XCTAssertNotNil(container)
    }

    func testBuilderWithEnvironmentKeyValue() {
        let builder = ContainerBuilder("redis:7")
            .withEnvironment("REDIS_PASSWORD", "secret123")
        let container = builder.build()
        XCTAssertNotNil(container)
    }

    func testBuilderWithMultipleEnvironmentVariables() {
        let builder = ContainerBuilder("mysql:8")
            .withEnvironment("MYSQL_ROOT_PASSWORD", "root")
            .withEnvironment("MYSQL_DATABASE", "testdb")
            .withEnvironment("MYSQL_USER", "testuser")
        let container = builder.build()
        XCTAssertNotNil(container)
    }

    func testBuilderWithLabelKeyValue() {
        let builder = ContainerBuilder("nginx:latest")
            .withLabel("env", "test")
        let container = builder.build()
        XCTAssertEqual(container.labels["env"], "test")
    }

    func testBuilderWithMultipleLabels() {
        let builder = ContainerBuilder("nginx:latest")
            .withLabel("env", "test")
            .withLabel("team", "backend")
            .withLabel("version", "1.0")
        let container = builder.build()
        XCTAssertEqual(container.labels.count, 3)
        XCTAssertEqual(container.labels["env"], "test")
        XCTAssertEqual(container.labels["team"], "backend")
        XCTAssertEqual(container.labels["version"], "1.0")
    }

    func testBuilderWithLabelDictionary() {
        let builder = ContainerBuilder("nginx:latest")
            .withLabel(["env": "production", "region": "us-east-1"])
        let container = builder.build()
        XCTAssertEqual(container.labels["env"], "production")
        XCTAssertEqual(container.labels["region"], "us-east-1")
    }

    func testBuilderWithPortBindingRandomHost() {
        let builder = ContainerBuilder("nginx:latest")
            .withPortBinding(80, assignRandomHostPort: true)
        let container = builder.build()
        XCTAssertNotNil(container)
    }

    func testBuilderWithPortBindingSpecificPorts() {
        let builder = ContainerBuilder("nginx:latest")
            .withPortBinding(hostPort: 8080, containerPort: 80)
        let container = builder.build()
        XCTAssertNotNil(container)
    }

    func testBuilderWithMultiplePortBindings() {
        let builder = ContainerBuilder("nginx:latest")
            .withPortBinding(80, assignRandomHostPort: true)
            .withPortBinding(443, assignRandomHostPort: true)
        let container = builder.build()
        XCTAssertNotNil(container)
    }

    func testBuilderWithWaitStrategy() {
        let builder = ContainerBuilder("nginx:latest")
            .withWaitStrategy(Wait.http(port: 80))
        let container = builder.build()
        XCTAssertNotNil(container)
    }

    func testBuilderWithNetworkAliases() {
        let builder = ContainerBuilder("nginx:latest")
            .withNetworkAliases(["web", "frontend"])
        let container = builder.build()
        XCTAssertNotNil(container)
    }

    func testBuilderWithEntrypoint() {
        let builder = ContainerBuilder("alpine:latest")
            .withEntrypoint(["/bin/sh", "-c"])
        let container = builder.build()
        XCTAssertNotNil(container)
    }

    func testBuilderWithCmd() {
        let builder = ContainerBuilder("alpine:latest")
            .withCmd(["echo", "Hello World"])
        let container = builder.build()
        XCTAssertNotNil(container)
    }

    func testBuilderChainedConfiguration() {
        let builder = ContainerBuilder("postgres:15")
            .withName("test-postgres")
            .withEnvironment("POSTGRES_PASSWORD", "secret")
            .withEnvironment("POSTGRES_DB", "testdb")
            .withLabel("env", "test")
            .withPortBinding(5432, assignRandomHostPort: true)
            .withWaitStrategy(Wait.tcp(port: 5432))
        let container = builder.build()
        XCTAssertEqual(container.name, "test-postgres")
        XCTAssertEqual(container.labels["env"], "test")
        XCTAssertEqual(container.image, "postgres:15")
    }
}
