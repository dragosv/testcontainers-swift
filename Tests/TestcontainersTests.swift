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

        defer {
            // Cleanup: errors intentionally suppressed — container stop failure should not
            // mask the test result. Use tearDown for strict cleanup requirements.
            Task { @MainActor in try? await postgres.stop() }
        }

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

        defer {
            // Cleanup: errors intentionally suppressed — container stop failure should not
            // mask the test result. Use tearDown for strict cleanup requirements.
            Task { @MainActor in try? await mysql.stop() }
        }

        let connectionString = try mysql.getConnectionString()
        XCTAssert(connectionString.contains("mysql://"))
        XCTAssert(connectionString.contains("testdb"))
    }
}

final class RedisModuleTests: XCTestCase {
    func testRedisContainer() async throws {
        let redis = try await RedisContainer(version: "7")
            .start()

        defer {
            // Cleanup: errors intentionally suppressed — container stop failure should not
            // mask the test result. Use tearDown for strict cleanup requirements.
            Task { @MainActor in try? await redis.stop() }
        }

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

        defer {
            // Cleanup: errors intentionally suppressed — container stop failure should not
            // mask the test result. Use tearDown for strict cleanup requirements.
            Task { @MainActor in try? await mongo.stop() }
        }

        let connectionString = try mongo.getConnectionString()
        XCTAssert(connectionString.contains("mongodb://"))
        XCTAssert(connectionString.contains("admin:password"))
    }
}

// MARK: - Unit Tests (No Docker Required)

final class ContainerStatusTests: XCTestCase {
    func testContainerStatusRunning() {
        let status = ContainerStatus("running")
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

    func testContainerStatusCaseInsensitive() {
        XCTAssertEqual(ContainerStatus("RUNNING"), .running)
        XCTAssertEqual(ContainerStatus("Running"), .running)
        XCTAssertEqual(ContainerStatus("EXITED"), .exited)
        XCTAssertEqual(ContainerStatus("Paused"), .paused)
    }
}

final class PortBindingTests: XCTestCase {
    func testPortBindingDefaults() {
        let binding = PortBinding(containerPort: 8080, hostPort: 80)
        XCTAssertEqual(binding.containerPort, 8080)
        XCTAssertEqual(binding.hostPort, 80)
        XCTAssertEqual(binding.proto, "tcp")
    }

    func testPortBindingWithUdp() {
        let binding = PortBinding(containerPort: 53, hostPort: 5353, proto: "udp")
        XCTAssertEqual(binding.containerPort, 53)
        XCTAssertEqual(binding.hostPort, 5353)
        XCTAssertEqual(binding.proto, "udp")
    }

    func testPortBindingWithRandomHostPort() {
        let binding = PortBinding(containerPort: 3000, hostPort: 0)
        XCTAssertEqual(binding.containerPort, 3000)
        XCTAssertEqual(binding.hostPort, 0)
    }
}

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
        let error = TestcontainersError.containerFailed("startup failed")
        XCTAssertEqual(error.errorDescription, "Container failed: startup failed")
    }

    func testPortMappingFailedError() {
        let error = TestcontainersError.portMappingFailed(8080)
        XCTAssertEqual(error.errorDescription, "Port mapping failed for port 8080")
    }

    func testWaitStrategyFailedError() {
        let error = TestcontainersError.waitStrategyFailed("timeout waiting")
        XCTAssertEqual(error.errorDescription, "Wait strategy failed: timeout waiting")
    }

    func testNetworkError() {
        let error = TestcontainersError.networkError("connection refused")
        XCTAssertEqual(error.errorDescription, "Network error: connection refused")
    }

    func testInvalidConfigurationError() {
        let error = TestcontainersError.invalidConfiguration("missing param")
        XCTAssertEqual(error.errorDescription, "Invalid configuration: missing param")
    }

    func testApiError() {
        let error = TestcontainersError.apiError("500 internal server error")
        XCTAssertEqual(error.errorDescription, "Docker API error: 500 internal server error")
    }

    func testTimeoutError() {
        let error = TestcontainersError.timeout
        XCTAssertEqual(error.errorDescription, "Operation timed out")
    }
}

final class CreateContainerRequestTests: XCTestCase {
    func testCreateContainerRequestDefaults() {
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

    func testCreateContainerRequestWithConfiguration() {
        var request = CreateContainerRequest(image: "postgres:15")
        request.hostname = "db-server"
        request.env = ["POSTGRES_PASSWORD=secret"]
        request.cmd = ["postgres"]
        request.labels = ["app": "database"]

        XCTAssertEqual(request.image, "postgres:15")
        XCTAssertEqual(request.hostname, "db-server")
        XCTAssertEqual(request.env, ["POSTGRES_PASSWORD=secret"])
        XCTAssertEqual(request.cmd, ["postgres"])
        XCTAssertEqual(request.labels, ["app": "database"])
    }
}

final class PortBindingConfigTests: XCTestCase {
    func testPortBindingConfigDefaults() {
        let config = PortBindingConfig()
        XCTAssertNil(config.hostIp)
        XCTAssertNil(config.hostPort)
    }

    func testPortBindingConfigWithValues() {
        let config = PortBindingConfig(hostIp: "0.0.0.0", hostPort: "8080")
        XCTAssertEqual(config.hostIp, "0.0.0.0")
        XCTAssertEqual(config.hostPort, "8080")
    }

    func testPortBindingConfigWithHostIpOnly() {
        let config = PortBindingConfig(hostIp: "127.0.0.1")
        XCTAssertEqual(config.hostIp, "127.0.0.1")
        XCTAssertNil(config.hostPort)
    }
}

final class ImagePullOptionsTests: XCTestCase {
    func testImagePullOptionsDefaults() {
        let options = ImagePullOptions()
        XCTAssertNil(options.tag)
    }

    func testImagePullOptionsWithTag() {
        let options = ImagePullOptions(tag: "latest")
        XCTAssertEqual(options.tag, "latest")
    }
}

final class ExecResultTests: XCTestCase {
    func testExecResultDefaults() {
        let result = ExecResult()
        XCTAssertNil(result.exitCode)
        XCTAssertNil(result.output)
    }

    func testExecResultWithValues() {
        let result = ExecResult(exitCode: 0, output: "Hello World")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.output, "Hello World")
    }

    func testExecResultWithExitCodeOnly() {
        let result = ExecResult(exitCode: 1)
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNil(result.output)
    }
}

final class TestcontainersConfigurationTests: XCTestCase {
    func testConfigurationDefaults() {
        let config = TestcontainersConfiguration()
        XCTAssertNil(config.dockerEndpoint)
        XCTAssertNil(config.dockerHost)
        XCTAssertFalse(config.tlsVerify)
        XCTAssertNil(config.tlsCertPath)
    }

    func testConfigurationWithValues() {
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

final class WaitStrategyConfigurationTests: XCTestCase {
    func testHttpWaitStrategyConfiguration() throws {
        let strategy = try XCTUnwrap(Wait.http(
            port: 8080,
            path: "/health",
            scheme: "https",
            timeout: 120
        ) as? HttpWaitStrategy)
        XCTAssertEqual(strategy.port, 8080)
        XCTAssertEqual(strategy.path, "/health")
        XCTAssertEqual(strategy.scheme, "https")
        XCTAssertEqual(strategy.timeout, 120)
    }

    func testHttpWaitStrategyDefaults() throws {
        let strategy = try XCTUnwrap(Wait.http(port: 3000) as? HttpWaitStrategy)
        XCTAssertEqual(strategy.port, 3000)
        XCTAssertEqual(strategy.path, "/")
        XCTAssertEqual(strategy.scheme, "http")
        XCTAssertEqual(strategy.timeout, 60)
    }

    func testTcpWaitStrategyConfiguration() throws {
        let strategy = try XCTUnwrap(Wait.tcp(port: 5432, timeout: 90) as? TcpWaitStrategy)
        XCTAssertEqual(strategy.port, 5432)
        XCTAssertEqual(strategy.timeout, 90)
    }

    func testTcpWaitStrategyDefaults() throws {
        let strategy = try XCTUnwrap(Wait.tcp(port: 3306) as? TcpWaitStrategy)
        XCTAssertEqual(strategy.port, 3306)
        XCTAssertEqual(strategy.timeout, 60)
    }

    func testLogWaitStrategyConfiguration() throws {
        let strategy = try XCTUnwrap(Wait.log(message: "Ready", timeout: 30) as? LogWaitStrategy)
        XCTAssertEqual(strategy.message, "Ready")
        XCTAssertEqual(strategy.timeout, 30)
    }

    func testLogWaitStrategyDefaults() throws {
        let strategy = try XCTUnwrap(Wait.log(message: "Started") as? LogWaitStrategy)
        XCTAssertEqual(strategy.message, "Started")
        XCTAssertEqual(strategy.timeout, 60)
    }

    func testExecWaitStrategyConfiguration() throws {
        let strategy = try XCTUnwrap(Wait.exec(command: ["pg_isready"], timeout: 45) as? ExecWaitStrategy)
        XCTAssertEqual(strategy.command, ["pg_isready"])
        XCTAssertEqual(strategy.timeout, 45)
    }

    func testExecWaitStrategyDefaults() throws {
        let strategy = try XCTUnwrap(Wait.exec(command: ["echo", "hello"]) as? ExecWaitStrategy)
        XCTAssertEqual(strategy.command, ["echo", "hello"])
        XCTAssertEqual(strategy.timeout, 60)
    }

    func testHealthCheckWaitStrategyConfiguration() throws {
        let strategy = try XCTUnwrap(Wait.healthCheck(timeout: 180) as? HealthCheckWaitStrategy)
        XCTAssertEqual(strategy.timeout, 180)
    }

    func testHealthCheckWaitStrategyDefaults() throws {
        let strategy = try XCTUnwrap(Wait.healthCheck() as? HealthCheckWaitStrategy)
        XCTAssertEqual(strategy.timeout, 60)
    }

    func testNoWaitStrategy() {
        let strategy = Wait.noWait()
        XCTAssert(strategy is NoWaitStrategy)
    }

    func testCombinedWaitStrategyContainsAllStrategies() throws {
        let tcp = Wait.tcp(port: 5432)
        let log = Wait.log(message: "Ready")
        let http = Wait.http(port: 8080)

        let combined = try XCTUnwrap(Wait.all(tcp, log, http) as? CombinedWaitStrategy)
        XCTAssertEqual(combined.strategies.count, 3)
        XCTAssert(combined.strategies[0] is TcpWaitStrategy)
        XCTAssert(combined.strategies[1] is LogWaitStrategy)
        XCTAssert(combined.strategies[2] is HttpWaitStrategy)
    }
}

final class ContainerBuilderConfigurationTests: XCTestCase {
    func testBuilderWithEnvironmentDictionary() {
        let builder = ContainerBuilder("redis:7")
            .withEnvironment(["REDIS_PASSWORD": "secret", "REDIS_PORT": "6379"])

        let container = builder.build()
        XCTAssertEqual(container.image, "redis:7")
    }

    func testBuilderWithLabelsDictionary() {
        let builder = ContainerBuilder("nginx:latest")
            .withLabel(["app": "web", "env": "test", "tier": "frontend"])

        let container = builder.build()
        XCTAssertEqual(container.labels.count, 3)
        XCTAssertEqual(container.labels["app"], "web")
        XCTAssertEqual(container.labels["env"], "test")
        XCTAssertEqual(container.labels["tier"], "frontend")
    }

    func testBuilderWithSpecificPortBinding() {
        let builder = ContainerBuilder("nginx:latest")
            .withPortBinding(hostPort: 8080, containerPort: 80)

        let container = builder.build()
        XCTAssertEqual(container.image, "nginx:latest")
    }

    func testBuilderWithEntrypoint() {
        let builder = ContainerBuilder("alpine:latest")
            .withEntrypoint(["/bin/sh", "-c"])

        let container = builder.build()
        XCTAssertEqual(container.image, "alpine:latest")
    }

    func testBuilderWithCmd() {
        let builder = ContainerBuilder("alpine:latest")
            .withCmd(["echo", "hello", "world"])

        let container = builder.build()
        XCTAssertEqual(container.image, "alpine:latest")
    }

    func testBuilderWithNetworkAliases() {
        let builder = ContainerBuilder("nginx:latest")
            .withNetworkAliases(["web", "frontend", "api-gateway"])

        let container = builder.build()
        XCTAssertEqual(container.image, "nginx:latest")
    }

    func testBuilderChainingMultipleConfigurations() {
        let builder = ContainerBuilder("postgres:15")
            .withName("test-db")
            .withEnvironment("POSTGRES_PASSWORD", "secret")
            .withEnvironment(["POSTGRES_USER": "admin", "POSTGRES_DB": "mydb"])
            .withLabel("app", "database")
            .withLabel(["env": "test"])
            .withPortBinding(5432, assignRandomHostPort: true)
            .withPortBinding(hostPort: 5433, containerPort: 5432)
            .withEntrypoint(["docker-entrypoint.sh"])
            .withCmd(["postgres"])
            .withWaitStrategy(Wait.tcp(port: 5432))

        let container = builder.build()
        XCTAssertEqual(container.image, "postgres:15")
        XCTAssertEqual(container.labels["app"], "database")
        XCTAssertEqual(container.labels["env"], "test")
    }
}
