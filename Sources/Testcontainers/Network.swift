import Foundation

// MARK: - Docker Network

/// A Docker network implementation for managing container networks.
public class DockerNetworkImpl {
    /// The network ID.
    public let id: String
    /// The network name.
    public let name: String
    /// The network driver.
    public let driver: String
    private let client: DockerClient
    
    /// Initializes a new Docker network implementation.
    /// - Parameters:
    ///   - id: The network ID.
    ///   - name: The network name.
    ///   - driver: The network driver, defaults to "bridge".
    ///   - client: The Docker client.
    public init(id: String, name: String, driver: String = "bridge", client: DockerClient) {
        self.id = id
        self.name = name
        self.driver = driver
        self.client = client
    }
    
    /// Connects a container to this network.
    /// - Parameter id: The container ID.
    /// - Throws: An error if connecting fails.
    public func connectContainer(id: String) async throws {
        try await client.connectNetwork(networkId: self.id, containerId: id)
    }
    
    /// Disconnects a container from this network.
    /// - Parameter id: The container ID.
    /// - Throws: An error if disconnecting fails.
    public func disconnectContainer(id: String) async throws {
        try await client.disconnectNetwork(networkId: self.id, containerId: id)
    }
    
    /// Deletes the network.
    /// - Throws: An error if deleting the network fails.
    public func delete() async throws {
        // Would require DELETE network endpoint in client
        // Not implemented yet
    }
}

// MARK: - Network Builder

/// A builder class for creating Docker networks with a fluent API.
public class NetworkBuilder {
    private let name: String
    private var driver: String = "bridge"
    private var Internal: Bool = false
    private let client: DockerClient
    
    /// Initializes a new network builder.
    /// - Parameter name: The network name.
    public init(_ name: String) {
        self.name = name
        self.client = DockerClient.getInstance()
    }
    
    /// Sets the network driver.
    /// - Parameter driver: The driver name.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withDriver(_ driver: String) -> NetworkBuilder {
        self.driver = driver
        return self
    }
    
    /// Sets whether the network is internal.
    /// - Parameter internal: Whether the network is internal.
    /// - Returns: The builder instance for chaining.
    @discardableResult
    public func withInternal(_ internal: Bool) -> NetworkBuilder {
        self.Internal = `internal`
        return self
    }
    
    /// Builds and creates the network.
    /// - Returns: A Docker network instance.
    /// - Throws: An error if network creation fails.
    public func build() async throws -> DockerNetworkImpl {
        let networkId = try await client.createNetwork(name: name, driver: driver)
        return DockerNetworkImpl(id: networkId, name: name, driver: driver, client: client)
    }
}

// MARK: - Extension alias for backward compatibility

/// Type alias for backward compatibility.
public typealias DockerNetwork = DockerNetworkImpl
