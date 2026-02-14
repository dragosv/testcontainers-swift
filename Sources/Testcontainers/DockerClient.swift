import Foundation
import DockerClientSwift
import Logging

// MARK: - Error Types

/// Errors that can occur when using the Docker client.
public enum DockerClientError: Error {
    /// The provided URL is invalid.
    case invalidURL
    /// The response from Docker is invalid.
    case invalidResponse
    /// An HTTP error occurred.
    case httpError(statusCode: Int, body: String?)
    /// An error occurred while decoding the response.
    case decodingError(Error)
    /// An error occurred while encoding the request.
    case encodingError(Error)
    /// The Docker socket was not found.
    case socketNotFound
}

// MARK: - Testcontainers Docker Client

/// A Docker client wrapper for Testcontainers, built on top of DockerClientSwift.
/// Provides container lifecycle management, image operations, and network support.
public class TestcontainersDockerClient: @unchecked Sendable {
    private struct SharedState: Sendable {
        static let lock = NSLock()
        // Use a mutable class wrapper stored inside the lock-protected section
    }
    // Thread-safe singleton storage using a lock and a class-based box
    private final class Box: @unchecked Sendable {
        var value: TestcontainersDockerClient?
    }
    private static let _shared = Box()
    private static let _lock = NSLock()

    internal let client: DockerClientSwift.DockerClient
    internal let logger: Logger

    /// Initialize a Docker client
    /// - Parameters:
    ///   - socketPath: Path to Docker socket (auto-detected if nil)
    public init(socketPath: String? = nil) {
        let resolvedPath = socketPath ?? Self.detectSocketPath()
        self.client = DockerClientSwift.DockerClient(daemonSocket: resolvedPath)
        self.logger = Logger(label: "testcontainers-swift.docker-client")
    }

    /// Get or create the singleton instance
    /// - Returns: The shared Docker client instance.
    public static func getInstance() -> TestcontainersDockerClient {
        _lock.lock()
        defer { _lock.unlock() }
        if _shared.value == nil {
            _shared.value = TestcontainersDockerClient()
        }
        return _shared.value!
    }

    /// Shutdown the Docker client
    /// - Throws: An error if shutdown fails.
    public func shutdown() async throws {
        try await client.shutdown()
    }

    // MARK: - Socket Detection

    private static func detectSocketPath() -> String {
        if let dockerHost = ProcessInfo.processInfo.environment["DOCKER_HOST"],
           let socket = socketPath(fromDockerHost: dockerHost)
        {
            return socket
        }

        #if os(macOS)
        if FileManager.default.fileExists(atPath: "/var/run/docker.sock") {
            return "/var/run/docker.sock"
        }

        let homeSocketPath = "\(NSHomeDirectory())/.docker/run/docker.sock"
        if FileManager.default.fileExists(atPath: homeSocketPath) {
            return homeSocketPath
        }
        #elseif os(Linux)
        if FileManager.default.fileExists(atPath: "/var/run/docker.sock") {
            return "/var/run/docker.sock"
        }
        #endif

        return "/var/run/docker.sock"
    }

    private static func socketPath(fromDockerHost dockerHost: String) -> String? {
        let unixPrefix = "unix://"
        guard dockerHost.hasPrefix(unixPrefix) else {
            return nil
        }
        let path = String(dockerHost.dropFirst(unixPrefix.count))
        return path.isEmpty ? nil : path
    }

    // MARK: - Container Operations

    /// Create a new container
    /// - Parameters:
    ///   - request: The container creation request.
    ///   - name: Optional name for the container.
    /// - Returns: The ID of the created container.
    /// - Throws: An error if container creation fails.
    public func createContainer(
        request: CreateContainerRequest,
        name: String? = nil
    ) async throws -> String {
        // Build port bindings for DockerClientSwift
        var portBindings: [DockerClientSwift.PortBinding] = []

        if let requestPortBindings = request.portBindings {
            for (portSpec, configs) in requestPortBindings {
                let parts = portSpec.split(separator: "/")
                guard let containerPort = UInt16(parts[0]) else { continue }

                for config in configs {
                    let hostPort = UInt16(config.hostPort ?? "0") ?? 0
                    portBindings.append(
                        DockerClientSwift.PortBinding(
                            hostIP: config.hostIp ?? "0.0.0.0",
                            hostPort: hostPort,
                            containerPort: containerPort
                        )
                    )
                }
            }
        }

        // Build the image reference
        let image = DockerClientSwift.Image(id: DockerClientSwift.Identifier<DockerClientSwift.Image>(request.image))

        // Create container via DockerClientSwift
        let container = try await client.containers.createContainer(
            image: image,
            commands: request.cmd,
            portBindings: portBindings
        )

        return container.id.value
    }

    /// Start a container
    /// - Parameter id: The container ID or name.
    /// - Throws: An error if starting the container fails.
    public func start(id: String) async throws {
        let container = try await getDockerClientSwiftContainer(id: id)
        _ = try await client.containers.start(container: container)
    }

    /// Start a container (alternative name)
    /// - Parameter id: The container ID or name.
    /// - Throws: An error if starting the container fails.
    public func startContainer(id: String) async throws {
        try await start(id: id)
    }

    /// Stop a container
    /// - Parameters:
    ///   - id: The container ID or name.
    ///   - timeout: The timeout in seconds, defaults to 10.
    /// - Throws: An error if stopping the container fails.
    public func stopContainer(id: String, timeout: Int = 10) async throws {
        let container = try await getDockerClientSwiftContainer(id: id)
        try await client.containers.stop(container: container)
    }

    /// Remove a container
    /// - Parameters:
    ///   - id: The container ID or name.
    ///   - force: Whether to force removal, defaults to true.
    /// - Throws: An error if removing the container fails.
    public func removeContainer(id: String, force: Bool = true) async throws {
        let container = try await getDockerClientSwiftContainer(id: id)
        try await client.containers.remove(container: container)
    }

    /// Inspect a container
    /// - Parameter id: The container ID or name.
    /// - Returns: Detailed container inspection information.
    /// - Throws: An error if inspecting the container fails.
    public func inspectContainer(id: String) async throws -> ContainerInspect {
        let container = try await client.containers.get(containerByNameOrId: id)

        // We need the raw inspect data, so we do a direct call
        let response = try await client.containers.get(containerByNameOrId: id)

        // Build ContainerInspect from the DockerClientSwift response
        // We need to get the raw inspect response for detailed info
        let rawInspect = try await getRawContainerInspect(id: id)
        return rawInspect
    }

    /// List containers
    /// - Parameter all: Whether to include stopped containers, defaults to false.
    /// - Returns: An array of Docker containers.
    /// - Throws: An error if listing containers fails.
    public func listContainers(all: Bool = false) async throws -> [DockerContainer] {
        let containers = try await client.containers.list(all: all)
        return containers.map { container in
            DockerContainer(
                id: container.id.value,
                state: container.state,
                image: container.image.id.value,
                names: container.names,
                ports: [],
                labels: nil
            )
        }
    }

    /// Get container logs
    /// - Parameters:
    ///   - containerId: The container ID or name.
    ///   - stdout: Whether to include stdout, defaults to true.
    ///   - stderr: Whether to include stderr, defaults to true.
    ///   - tail: Number of lines to tail, optional.
    /// - Returns: The container logs as a string.
    /// - Throws: An error if retrieving logs fails.
    public func getContainerLogs(
        containerId: String,
        stdout: Bool = true,
        stderr: Bool = true,
        tail: Int? = nil
    ) async throws -> String {
        let container = try await getDockerClientSwiftContainer(id: containerId)
        return try await client.containers.logs(container: container)
    }

    /// Create an exec instance
    /// - Parameters:
    ///   - containerId: The container ID or name.
    ///   - cmd: The command to execute.
    ///   - attachStdout: Whether to attach stdout, defaults to true.
    ///   - attachStderr: Whether to attach stderr, defaults to true.
    /// - Returns: An exec instance.
    /// - Throws: An error if creating the exec instance fails.
    public func execCreate(
        containerId: String,
        cmd: [String],
        attachStdout: Bool = true,
        attachStderr: Bool = true
    ) async throws -> ExecInstance {
        // DockerClientSwift doesn't have exec support directly, fall back to raw API
        let execResult = try await execViaRawAPI(containerId: containerId, cmd: cmd)
        return ExecInstance(id: execResult)
    }

    /// Start an exec instance
    /// - Parameter execId: The exec instance ID.
    /// - Returns: The output of the exec command.
    /// - Throws: An error if starting the exec instance fails.
    public func execStart(execId: String) async throws -> String {
        return try await execStartViaRawAPI(execId: execId)
    }

    // MARK: - Image Operations

    /// Pull an image
    /// - Parameter image: The image name or identifier to pull.
    /// - Throws: An error if pulling the image fails.
    public func pullImage(image: String) async throws {
        _ = try await client.images.pullImage(byIdentifier: image)
    }

    /// Remove an image
    /// - Parameters:
    ///   - name: The image name or ID.
    ///   - force: Whether to force removal, defaults to false.
    /// - Throws: An error if removing the image fails.
    public func removeImage(_ name: String, force: Bool = false) async throws {
        let image = try await client.images.get(imageByNameOrId: name)
        try await client.images.remove(image: image, force: force)
    }

    // MARK: - Network Operations

    /// Create a network
    /// - Parameters:
    ///   - name: The network name.
    ///   - driver: The network driver, defaults to "bridge".
    /// - Returns: The ID of the created network.
    /// - Throws: An error if network creation fails.
    public func createNetwork(name: String, driver: String = "bridge") async throws -> String {
        // DockerClientSwift doesn't have network support, fall back to raw API
        return try await createNetworkViaRawAPI(name: name, driver: driver)
    }

    /// Connect a container to a network
    /// - Parameters:
    ///   - networkId: The network ID.
    ///   - containerId: The container ID.
    /// - Throws: An error if connecting fails.
    public func connectNetwork(networkId: String, containerId: String) async throws {
        try await connectNetworkViaRawAPI(networkId: networkId, containerId: containerId)
    }

    /// Disconnect a container from a network
    /// - Parameters:
    ///   - networkId: The network ID.
    ///   - containerId: The container ID.
    /// - Throws: An error if disconnecting fails.
    public func disconnectNetwork(networkId: String, containerId: String) async throws {
        try await disconnectNetworkViaRawAPI(networkId: networkId, containerId: containerId)
    }

    /// Remove a network
    /// - Parameter id: The network ID.
    /// - Throws: An error if removing the network fails.
    public func removeNetwork(id: String) async throws {
        try await removeNetworkViaRawAPI(id: id)
    }

    // MARK: - System Operations

    /// Get Docker version
    /// - Returns: Docker version information.
    /// - Throws: An error if retrieving version fails.
    public func getVersion() async throws -> Version {
        let dockerVersion = try await client.version()
        return Version(
            version: dockerVersion.version,
            apiVersion: dockerVersion.minAPIVersion,
            minAPIVersion: dockerVersion.minAPIVersion,
            gitCommit: nil,
            goVersion: nil,
            os: dockerVersion.os,
            arch: dockerVersion.architecture
        )
    }

    /// Ping the Docker daemon
    /// - Returns: True if Docker is reachable, false otherwise.
    /// - Throws: An error if the ping operation fails.
    public func ping() async throws -> Bool {
        do {
            _ = try await client.version()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    private func getDockerClientSwiftContainer(id: String) async throws -> DockerClientSwift.Container {
        return try await client.containers.get(containerByNameOrId: id)
    }

    /// Raw API call for container inspect (needed for detailed port/network info)
    private func getRawContainerInspect(id: String) async throws -> ContainerInspect {
        // Use the underlying DockerClientSwift client to make a raw endpoint call
        let endpoint = RawInspectContainerEndpoint(nameOrId: id)
        let response = try await client.run(endpoint)
        return response
    }

    /// Raw API call for exec create
    private func execViaRawAPI(containerId: String, cmd: [String]) async throws -> String {
        let endpoint = RawExecCreateEndpoint(containerId: containerId, cmd: cmd)
        let response = try await client.run(endpoint)
        return response.Id
    }

    /// Raw API call for exec start
    private func execStartViaRawAPI(execId: String) async throws -> String {
        let endpoint = RawExecStartEndpoint(execId: execId)
        let response = try await client.run(endpoint)
        return response
    }

    /// Raw API call for network create
    private func createNetworkViaRawAPI(name: String, driver: String) async throws -> String {
        let endpoint = RawCreateNetworkEndpoint(name: name, driver: driver)
        let response = try await client.run(endpoint)
        return response.Id
    }

    /// Raw API call for network connect
    private func connectNetworkViaRawAPI(networkId: String, containerId: String) async throws {
        let endpoint = RawConnectNetworkEndpoint(networkId: networkId, containerId: containerId)
        let _: NoBody? = try await client.run(endpoint)
    }

    /// Raw API call for network disconnect
    private func disconnectNetworkViaRawAPI(networkId: String, containerId: String) async throws {
        let endpoint = RawDisconnectNetworkEndpoint(networkId: networkId, containerId: containerId)
        let _: NoBody? = try await client.run(endpoint)
    }

    /// Raw API call for network remove
    private func removeNetworkViaRawAPI(id: String) async throws {
        let endpoint = RawRemoveNetworkEndpoint(networkId: id)
        let _: NoBody? = try await client.run(endpoint)
    }
}

// Keep backward compatibility: typealias so existing code using `DockerClient` still works
public typealias DockerClient = TestcontainersDockerClient

// MARK: - Container Reference

/// A reference to a container with its associated Docker client.
public class ContainerReference {
    /// The container ID.
    public let id: String
    /// The Docker client used to manage the container.
    public let client: TestcontainersDockerClient

    /// Initializes a new container reference.
    /// - Parameters:
    ///   - id: The container ID.
    ///   - client: The Docker client.
    public init(id: String, client: TestcontainersDockerClient) {
        self.id = id
        self.client = client
    }
}
