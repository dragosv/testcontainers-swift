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
    /// The unique identifier of the container.
    public let id: String
    /// The name of the container, if assigned.
    public private(set) var name: String?
    /// The Docker image used by the container.
    public let image: String
    /// The host where the container is running.
    public private(set) var host: String?
    /// The IP address of the container.
    public private(set) var ipAddress: String?
    /// The labels associated with the container.
    public let labels: [String: String]
    
    private let client: DockerClient
    private var portMappings: [Int: Int] = [:]
    private var inspect: ContainerInspect?
    
    /// Initializes a new Docker container implementation.
    /// - Parameters:
    ///   - id: The container ID.
    ///   - image: The Docker image.
    ///   - client: The Docker client.
    ///   - name: The container name.
    ///   - labels: The container labels.
    init(id: String, image: String, client: DockerClient, name: String? = nil, labels: [String: String] = [:]) {
        self.id = id
        self.image = image
        self.client = client
        self.name = name
        self.labels = labels
    }
    
    /// Starts the container.
    /// - Throws: An error if the container fails to start.
    public func start() async throws {
        try await client.start(id: id)
        try await updateInspectInfo()
    }
    
    /// Stops the container with the specified timeout.
    /// - Parameter timeout: The timeout in seconds, defaults to 10.
    /// - Throws: An error if the container fails to stop.
    public func stop(timeout: Int = 10) async throws {
        try await client.stopContainer(id: id, timeout: timeout)
    }
    
    /// Deletes the container.
    /// - Throws: An error if the container fails to be deleted.
    public func delete() async throws {
        try await client.removeContainer(id: id, force: true)
    }
    
    /// Gets the mapped host port for the specified container port.
    /// - Parameter containerPort: The port number inside the container.
    /// - Returns: The mapped host port.
    /// - Throws: An error if the port mapping is not found.
    public func getMappedPort(_ containerPort: Int) throws -> Int {
        // Check cached mappings
        if let mappedPort = portMappings[containerPort] {
            return mappedPort
        }
        
        // Try to find from inspect
        if let inspect = inspect,
           let portInfos = inspect.networkSettings.ports?["\(containerPort)/tcp"],
           let portInfosArray = portInfos,
           let firstPortInfo = portInfosArray.first,
           let hostPort = Int(firstPortInfo.hostPort) {
            portMappings[containerPort] = hostPort
            return hostPort
        }
        
        throw TestcontainersError.portMappingFailed(containerPort)
    }
    
    /// Executes a command inside the container.
    /// - Parameter command: The command to execute as an array of strings.
    /// - Returns: The output of the command.
    /// - Throws: An error if the command fails.
    public func exec(command: [String]) async throws -> String {
        let exec = try await client.execCreate(containerId: id, cmd: command)
        return try await client.execStart(execId: exec.id)
    }
    
    /// Gets the logs from the container.
    /// - Returns: The container logs as a string.
    /// - Throws: An error if retrieving logs fails.
    public func getLogs() async throws -> String {
        try await client.getContainerLogs(containerId: id)
    }
    
    /// Gets the current state of the container.
    /// - Returns: The container status.
    /// - Throws: An error if retrieving the state fails.
    public func getState() async throws -> ContainerStatus {
        try await updateInspectInfo()
        let inspect = try await client.inspectContainer(id: id)
        return ContainerStatus(inspect.state.status)
    }
    
    private func updateInspectInfo() async throws {
        self.inspect = try await client.inspectContainer(id: id)
        
        // Extract hostname/IP from inspect
        if let networkSettings = self.inspect?.networkSettings {
            if let networks = networkSettings.networks,
               let firstNetwork = networks.values.first {
                self.ipAddress = firstNetwork.ipAddress
            }
        }
        
        self.host = ipAddress ?? "localhost"
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
    /// - Parameter image: The Docker image to use for the container.
    public init(_ image: String) {
        self.image = image
        self.client = DockerClient.getInstance()
    }
    
    // MARK: - Configuration Methods
    
    /// Sets the name of the container.
    /// - Parameter name: The container name.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withName(_ name: String) -> ContainerBuilder {
        self.name = name
        return self
    }
    
    /// Sets environment variables from a dictionary.
    /// - Parameter env: A dictionary of environment variables.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withEnvironment(_ env: [String: String]) -> ContainerBuilder {
        self.environment.merge(env) { _, new in new }
        return self
    }
    
    /// Sets a single environment variable.
    /// - Parameters:
    ///   - key: The environment variable key.
    ///   - value: The environment variable value.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withEnvironment(_ key: String, _ value: String) -> ContainerBuilder {
        self.environment[key] = value
        return self
    }
    
    /// Sets a single label.
    /// - Parameters:
    ///   - key: The label key.
    ///   - value: The label value.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withLabel(_ key: String, _ value: String) -> ContainerBuilder {
        self.labels[key] = value
        return self
    }
    
    /// Sets multiple labels from a dictionary.
    /// - Parameter labels: A dictionary of labels.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withLabel(_ labels: [String: String]) -> ContainerBuilder {
        self.labels.merge(labels) { _, new in new }
        return self
    }
    
    /// Configures port binding with optional random host port assignment.
    /// - Parameters:
    ///   - containerPort: The port inside the container.
    ///   - assignRandomHostPort: Whether to assign a random host port.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withPortBinding(_ containerPort: Int, assignRandomHostPort: Bool) -> ContainerBuilder {
        let hostPort = assignRandomHostPort ? 0 : containerPort
        let binding = PortBinding(containerPort: containerPort, hostPort: hostPort)
        portBindings.append(binding)
        exposedPorts.append(containerPort)
        return self
    }
    
    /// Configures port binding with specific host and container ports.
    /// - Parameters:
    ///   - hostPort: The port on the host.
    ///   - containerPort: The port inside the container.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withPortBinding(hostPort: Int, containerPort: Int) -> ContainerBuilder {
        let binding = PortBinding(containerPort: containerPort, hostPort: hostPort)
        portBindings.append(binding)
        exposedPorts.append(containerPort)
        return self
    }
    
    /// Sets the wait strategy for the container.
    /// - Parameter strategy: The wait strategy to use.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withWaitStrategy(_ strategy: WaitStrategy) -> ContainerBuilder {
        self.waitStrategy = strategy
        return self
    }
    
    /// Sets the network for the container.
    /// - Parameter network: The Docker network.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withNetwork(_ network: DockerNetwork) -> ContainerBuilder {
        self.network = network
        return self
    }
    
    /// Sets network aliases for the container.
    /// - Parameter aliases: An array of network aliases.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withNetworkAliases(_ aliases: [String]) -> ContainerBuilder {
        self.networkAliases.append(contentsOf: aliases)
        return self
    }
    
    /// Sets the entrypoint for the container.
    /// - Parameter entrypoint: The entrypoint as an array of strings.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withEntrypoint(_ entrypoint: [String]) -> ContainerBuilder {
        self.entrypoint = entrypoint
        return self
    }
    
    /// Sets the command for the container.
    /// - Parameter cmd: The command as an array of strings.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withCmd(_ cmd: [String]) -> ContainerBuilder {
        self.cmd = cmd
        return self
    }
    
    // MARK: - Build
    
    /// Builds a container instance without creating it in Docker.
    /// - Returns: A container instance.
    public func build() -> Container {
        return DockerContainerImpl(
            id: UUID().uuidString,
            image: image,
            client: client,
            name: name,
            labels: labels
        )
    }
    
    // MARK: - Create and Start
    
    /// Builds and creates the container in Docker.
    /// - Returns: A container instance.
    /// - Throws: An error if the container creation fails.
    public func buildAsync() async throws -> Container {
        // Pull the image first
        try await client.pullImage(image: image)
        
        // Create Container configuration
        var request = CreateContainerRequest(image: image)
        request.hostname = name
        request.labels = labels
        
        // Set environment variables
        if !environment.isEmpty {
            request.env = environment.map { "\($0.key)=\($0.value)" }
        }
        
        // Set entrypoint and cmd
        if let entrypoint = entrypoint {
            request.entrypoint = entrypoint
        }
        if let cmd = cmd {
            request.cmd = cmd
        }
        
        // Configure port bindings
        if !portBindings.isEmpty {
            request.exposedPorts = [:]
            request.portBindings = [:]
            
            for binding in portBindings {
                let portKey = "\(binding.containerPort)/\(binding.proto)"
                request.exposedPorts?[portKey] = [String: String]()
                
                if binding.hostPort > 0 {
                    request.portBindings?[portKey] = [
                        PortBindingConfig(hostIp: "0.0.0.0", hostPort: String(binding.hostPort))
                    ]
                } else {
                    request.portBindings?[portKey] = [
                        PortBindingConfig(hostIp: "0.0.0.0", hostPort: nil)
                    ]
                }
            }
        }
        
        // Create the Container
        let containerId = try await client.createContainer(request: request, name: name)
        
        // Create Container object
        let Container = DockerContainerImpl(
            id: containerId,
            image: image,
            client: client,
            name: name,
            labels: labels
        )
        
        // Connect to network if specified
        if let network = network {
            try await client.connectNetwork(networkId: network.id, containerId: containerId)
        }
        
        return Container
    }
}

// MARK: - Container Extension for Starting

extension Container {
    /// Starts the container and optionally waits for it to be ready using a wait strategy.
    /// - Parameter waitStrategy: An optional wait strategy to use after starting the container.
    /// - Throws: An error if starting the container or waiting fails.
    public func start(waitStrategy: WaitStrategy? = nil) async throws {
        try await start()
        
        if let strategy = waitStrategy {
            try await strategy.waitUntilReady(container: self, client: DockerClient.getInstance())
        }
    }
}
