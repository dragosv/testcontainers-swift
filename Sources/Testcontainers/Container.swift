import Foundation

// MARK: - Container Protocol

/// A protocol defining the lifecycle operations for a container.
public protocol Container: AnyObject {
    /// The unique identifier of the container.
    var id: String { get }
    /// The name of the container, if assigned.
    var name: String? { get }
    /// The Docker image used by the container.
    var image: String { get }
    /// The host where the container is running.
    var host: String? { get }
    /// The IP address of the container.
    var ipAddress: String? { get }
    /// The labels associated with the container.
    var labels: [String: String] { get }

    /// Starts the container.
    /// - Throws: An error if the container fails to start.
    func start() async throws
    /// Stops the container with the specified timeout.
    /// - Parameter timeout: The timeout in seconds to wait for the container to stop.
    /// - Throws: An error if the container fails to stop.
    func stop(timeout: Int) async throws
    /// Deletes the container.
    /// - Throws: An error if the container fails to be deleted.
    func delete() async throws
    /// Gets the mapped host port for the specified container port.
    /// - Parameter containerPort: The port number inside the container.
    /// - Returns: The mapped host port.
    /// - Throws: An error if the port mapping is not found.
    func getMappedPort(_ containerPort: Int) throws -> Int
    /// Executes a command inside the container.
    /// - Parameter command: The command to execute as an array of strings.
    /// - Returns: The output of the command.
    /// - Throws: An error if the command fails.
    func exec(command: [String]) async throws -> String
    /// Gets the logs from the container.
    /// - Returns: The container logs as a string.
    /// - Throws: An error if retrieving logs fails.
    func getLogs() async throws -> String
    /// Gets the current state of the container.
    /// - Returns: The container status.
    /// - Throws: An error if retrieving the state fails.
    func getState() async throws -> ContainerStatus
}

// MARK: - Docker Container Implementation

/// A concrete implementation of the Container protocol using Docker.
public class DockerContainerImpl: Container {
    public let id: String
    public private(set) var name: String?
    public let image: String
    public private(set) var host: String?
    public private(set) var ipAddress: String?
    public let labels: [String: String]

    private let client: DockerClient
    private var portMappings: [Int: Int] = [:]
    private var inspect: ContainerInspect?

    init(id: String, image: String, client: DockerClient, name: String? = nil, labels: [String: String] = [:]) {
        self.id = id
        self.image = image
        self.client = client
        self.name = name
        self.labels = labels
    }

    public func start() async throws {
        try await client.start(id: id)
        try await updateInspectInfo()
    }

    public func stop(timeout: Int = 10) async throws {
        try await client.stopContainer(id: id, timeout: timeout)
    }

    public func delete() async throws {
        try await client.removeContainer(id: id, force: true)
    }

    public func getMappedPort(_ containerPort: Int) throws -> Int {
        // Check cached mappings
        if let mappedPort = portMappings[containerPort] {
            return mappedPort
        }

        // Try to find from inspect
        if
            let inspect,
            let portInfos = inspect.networkSettings.ports?["\(containerPort)/tcp"],
            let portInfosArray = portInfos,
            let firstPortInfo = portInfosArray.first,
            let hostPort = Int(firstPortInfo.hostPort)
        {
            portMappings[containerPort] = hostPort
            return hostPort
        }

        throw TestcontainersError.portMappingFailed(containerPort)
    }

    public func exec(command: [String]) async throws -> String {
        let exec = try await client.execCreate(containerId: id, cmd: command)
        return try await client.execStart(execId: exec.id)
    }

    public func getLogs() async throws -> String {
        try await client.getContainerLogs(containerId: id)
    }

    public func getState() async throws -> ContainerStatus {
        try await updateInspectInfo()
        let inspect = try await client.inspectContainer(id: id)
        return ContainerStatus(inspect.state.status)
    }

    private func updateInspectInfo() async throws {
        inspect = try await client.inspectContainer(id: id)

        // Extract hostname/IP from inspect
        if let networkSettings = inspect?.networkSettings {
            if
                let networks = networkSettings.networks,
                let firstNetwork = networks.values.first
            {
                ipAddress = firstNetwork.ipAddress
            }
        }

        host = ipAddress ?? "localhost"
    }
}

// MARK: - Container Builder

/// A builder class for configuring and creating containers with a fluent API.
public class ContainerBuilder {
    private let image: String
    private var name: String?
    private var environment: [String: String] = [:]
    private var labels: [String: String] = [:]
    private var portBindings: [PortBinding] = []
    private var exposedPorts: [Int] = []
    private var entrypoint: [String]?
    private var cmd: [String]?
    private var waitStrategy: WaitStrategy = NoWaitStrategy()
    private var network: DockerNetwork?
    private var networkAliases: [String] = []
    private let client: DockerClient

    /// Initializes a new container builder with the specified image.
    public init(_ image: String) {
        self.image = image
        self.client = DockerClient.getInstance()
    }

    // MARK: - Configuration Methods

    @discardableResult
    public func withName(_ name: String) -> ContainerBuilder {
        self.name = name
        return self
    }

    @discardableResult
    public func withEnvironment(_ env: [String: String]) -> ContainerBuilder {
        environment.merge(env) { _, new in new }
        return self
    }

    @discardableResult
    public func withEnvironment(_ key: String, _ value: String) -> ContainerBuilder {
        environment[key] = value
        return self
    }

    @discardableResult
    public func withLabel(_ key: String, _ value: String) -> ContainerBuilder {
        labels[key] = value
        return self
    }

    @discardableResult
    public func withLabel(_ labels: [String: String]) -> ContainerBuilder {
        self.labels.merge(labels) { _, new in new }
        return self
    }

    @discardableResult
    public func withPortBinding(_ containerPort: Int, assignRandomHostPort: Bool) -> ContainerBuilder {
        let hostPort = assignRandomHostPort ? 0 : containerPort
        portBindings.append(PortBinding(containerPort: containerPort, hostPort: hostPort))
        exposedPorts.append(containerPort)
        return self
    }

    @discardableResult
    public func withPortBinding(hostPort: Int, containerPort: Int) -> ContainerBuilder {
        portBindings.append(PortBinding(containerPort: containerPort, hostPort: hostPort))
        exposedPorts.append(containerPort)
        return self
    }

    @discardableResult
    public func withWaitStrategy(_ strategy: WaitStrategy) -> ContainerBuilder {
        waitStrategy = strategy
        return self
    }

    @discardableResult
    public func withNetwork(_ network: DockerNetwork) -> ContainerBuilder {
        self.network = network
        return self
    }

    @discardableResult
    public func withNetworkAliases(_ aliases: [String]) -> ContainerBuilder {
        networkAliases.append(contentsOf: aliases)
        return self
    }

    @discardableResult
    public func withEntrypoint(_ entrypoint: [String]) -> ContainerBuilder {
        self.entrypoint = entrypoint
        return self
    }

    @discardableResult
    public func withCmd(_ cmd: [String]) -> ContainerBuilder {
        self.cmd = cmd
        return self
    }

    // MARK: - Build

    /// Builds a container instance without creating it in Docker (for testing).
    public func build() -> Container {
        DockerContainerImpl(
            id: UUID().uuidString,
            image: image,
            client: client,
            name: name,
            labels: labels
        )
    }

    // MARK: - Create and Start

    /// Builds and creates the container in Docker.
    public func buildAsync() async throws -> Container {
        try await client.pullImage(image: image)

        var request = CreateContainerRequest(image: image)
        request.hostname = name
        request.labels = labels

        if !environment.isEmpty {
            request.env = environment.map { "\($0.key)=\($0.value)" }
        }

        if let entrypoint {
            request.entrypoint = entrypoint
        }
        if let cmd {
            request.cmd = cmd
        }

        if !portBindings.isEmpty {
            request.exposedPorts = [:]
            request.portBindings = [:]

            for binding in portBindings {
                let portKey = "\(binding.containerPort)/\(binding.proto)"
                request.exposedPorts?[portKey] = [String: String]()

                if binding.hostPort > 0 {
                    request.portBindings?[portKey] = [
                        PortBindingConfig(hostIp: "0.0.0.0", hostPort: String(binding.hostPort)),
                    ]
                } else {
                    request.portBindings?[portKey] = [
                        PortBindingConfig(hostIp: "0.0.0.0", hostPort: nil),
                    ]
                }
            }
        }

        let containerId = try await client.createContainer(request: request, name: name)
        let Container = DockerContainerImpl(
            id: containerId,
            image: image,
            client: client,
            name: name,
            labels: labels
        )

        if let network {
            try await client.connectNetwork(networkId: network.id, containerId: containerId)
        }

        return Container
    }
}

// MARK: - Container Extension for Starting

public extension Container {
    /// Starts the container and optionally waits for it to be ready.
    func start(waitStrategy: WaitStrategy? = nil) async throws {
        try await start()

        if let strategy = waitStrategy {
            try await strategy.waitUntilReady(container: self, client: DockerClient.getInstance())
        }
    }
}
