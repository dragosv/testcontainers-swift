/// Docker image model
public struct Image: Codable {
    public let id: String
    public let repoTags: [String]?
    public let created: Int?
    public let size: Int?
    public let virtualSize: Int?
    public let labels: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case repoTags = "RepoTags"
        case created = "Created"
        case size = "Size"
        case virtualSize = "VirtualSize"
        case labels = "Labels"
    }
}

/// Docker system info model
public struct SystemInfo: Codable {
    public let id: String
    public let containers: Int
    public let images: Int
    public let operatingSystem: String
    public let kernelVersion: String
    public let architecture: String

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case containers = "Containers"
        case images = "Images"
        case operatingSystem = "OperatingSystem"
        case kernelVersion = "KernelVersion"
        case architecture = "Architecture"
    }
}

/// Docker version model
public struct Version: Codable {
    public let version: String
    public let apiVersion: String
    public let minAPIVersion: String?
    public let gitCommit: String?
    public let goVersion: String?
    public let os: String?
    public let arch: String?

    enum CodingKeys: String, CodingKey {
        case version = "Version"
        case apiVersion = "ApiVersion"
        case minAPIVersion = "MinAPIVersion"
        case gitCommit = "GitCommit"
        case goVersion = "GoVersion"
        case os = "Os"
        case arch = "Arch"
    }
}

import Foundation

// MARK: - Models

/// Represents a Docker container
public struct DockerContainer: Codable {
    public let id: String
    public let state: String
    public let image: String
    public let names: [String]
    public let ports: [DockerPortBinding]
    public let labels: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case state = "State"
        case image = "Image"
        case names = "Names"
        case ports = "Ports"
        case labels = "Labels"
    }
}

/// Represents a port binding from docker API
public struct DockerPortBinding: Codable {
    public let privatePort: Int
    public let publicPort: Int?
    public let type: String
    
    enum CodingKeys: String, CodingKey {
        case privatePort = "PrivatePort"
        case publicPort = "PublicPort"
        case type = "Type"
    }
}

/// Represents container inspection details
public struct ContainerInspect: Codable {
    public let id: String
    public let name: String
    public let state: ContainerState
    public let config: ContainerConfig
    public let networkSettings: NetworkSettings
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case state = "State"
        case config = "Config"
        case networkSettings = "NetworkSettings"
    }
}

/// Container state information
public struct ContainerState: Codable {
    public let status: String
    public let running: Bool
    public let paused: Bool
    public let restarting: Bool
    public let oomKilled: Bool?
    public let dead: Bool
    public let pid: Int
    public let exitCode: Int
    public let error: String?
    public let startedAt: String
    public let finishedAt: String
    
    enum CodingKeys: String, CodingKey {
        case status = "Status"
        case running = "Running"
        case paused = "Paused"
        case restarting = "Restarting"
        case oomKilled = "OomKilled"
        case dead = "Dead"
        case pid = "Pid"
        case exitCode = "ExitCode"
        case error = "Error"
        case startedAt = "StartedAt"
        case finishedAt = "FinishedAt"
    }
}

/// Container configuration
public struct ContainerConfig: Codable {
    public let image: String
    public let hostname: String?
    public let env: [String]?
    public let cmd: [String]?
    public let entrypoint: [String]?
    public let exposedPorts: [String: [String: String]]?
    public let labels: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case image = "Image"
        case hostname = "Hostname"
        case env = "Env"
        case cmd = "Cmd"
        case entrypoint = "Entrypoint"
        case exposedPorts = "ExposedPorts"
        case labels = "Labels"
    }
}

/// Network settings
public struct NetworkSettings: Codable {
    public let ports: [String: [PortInfo]?]?
    public let networks: [String: NetworkInfo]?
    
    enum CodingKeys: String, CodingKey {
        case ports = "Ports"
        case networks = "Networks"
    }
}

/// Port information
public struct PortInfo: Codable {
    public let hostIp: String
    public let hostPort: String
    
    enum CodingKeys: String, CodingKey {
        case hostIp = "HostIp"
        case hostPort = "HostPort"
    }
}

/// Network information
public struct NetworkInfo: Codable {
    public let ipAddress: String
    public let ipPrefixLen: Int
    public let gateway: String
    public let macAddress: String
    public let aliases: [String]?
    
    enum CodingKeys: String, CodingKey {
        case ipAddress = "IPAddress"
        case ipPrefixLen = "IPPrefixLen"
        case gateway = "Gateway"
        case macAddress = "MacAddress"
        case aliases = "Aliases"
    }
}

/// Container creation configuration
public struct CreateContainerRequest: Codable {
    public var image: String
    public var hostname: String?
    public var env: [String]?
    public var cmd: [String]?
    public var entrypoint: [String]?
    public var exposedPorts: [String: [String: String]]?
    public var labels: [String: String]?
    public var portBindings: [String: [PortBindingConfig]]?
    public var networkMode: String?
    
    enum CodingKeys: String, CodingKey {
        case image = "Image"
        case hostname = "Hostname"
        case env = "Env"
        case cmd = "Cmd"
        case entrypoint = "Entrypoint"
        case exposedPorts = "ExposedPorts"
        case labels = "Labels"
        case portBindings = "PortBindings"
        case networkMode = "NetworkMode"
    }
    
    public init(image: String) {
        self.image = image
    }
}

/// Port binding configuration
public struct PortBindingConfig: Codable {
    public let hostIp: String?
    public let hostPort: String?
    
    enum CodingKeys: String, CodingKey {
        case hostIp = "HostIp"
        case hostPort = "HostPort"
    }
    
    public init(hostIp: String? = nil, hostPort: String? = nil) {
        self.hostIp = hostIp
        self.hostPort = hostPort
    }
}

/// Docker network
public struct DockerNetworkInfo: Codable {
    public let name: String
    public let id: String
    public let driver: String
    public let containers: [String: NetworkContainer]?
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
        case driver = "Driver"
        case containers = "Containers"
    }
}

/// Network container information
public struct NetworkContainer: Codable {
    public let name: String
    public let endpointId: String
    public let macAddress: String
    public let ipAddress: String
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case endpointId = "EndpointID"
        case macAddress = "MacAddress"
        case ipAddress = "IPv4Address"
    }
}

/// Image pull options
public struct ImagePullOptions: Codable {
    public let tag: String?
    
    public init(tag: String? = nil) {
        self.tag = tag
    }
}

/// Exec instance
public struct ExecInstance: Codable {
    public let id: String
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
    }
}

/// Exec result
public struct ExecResult: Codable {
    public let exitCode: Int?
    public let output: String?
    
    public init(exitCode: Int? = nil, output: String? = nil) {
        self.exitCode = exitCode
        self.output = output
    }
}

// MARK: - Container State Enum

/// Represents the status of a Docker container.
public enum ContainerStatus {
    /// The container is currently running.
    case running
    /// The container has exited.
    case exited
    /// The container is paused.
    case paused
    /// The container has been created but not started.
    case created
    /// The container is restarting.
    case restarting
    /// The container is dead.
    case dead
    /// The container status is unknown.
    case unknown
    
    public init(_ status: String) {
        switch status.lowercased() {
        case "running":
            self = .running
        case "exited":
            self = .exited
        case "paused":
            self = .paused
        case "created":
            self = .created
        case "restarting":
            self = .restarting
        case "dead":
            self = .dead
        default:
            self = .unknown
        }
    }
}

// MARK: - Testcontainers Configuration

/// Configuration options for Testcontainers.
public struct TestcontainersConfiguration {
    /// The Docker endpoint URL.
    public var dockerEndpoint: String?
    /// The Docker host.
    public var dockerHost: String?
    /// Whether to verify TLS certificates.
    public var tlsVerify: Bool = false
    /// Path to TLS certificates.
    public var tlsCertPath: String?
    
    /// Initializes a new configuration.
    public init() {}
}

// MARK: - Wait Strategy Result

/// The result of a wait strategy execution.
public enum WaitResult {
    /// The wait condition was met successfully.
    case success
    /// The wait timed out.
    case timeout
    /// The wait failed with an error.
    case failure(Error)
}

// MARK: - Port Binding Models

/// Represents a port binding between container and host.
public struct PortBinding {
    /// The port number inside the container.
    public let containerPort: Int
    /// The port number on the host.
    public let hostPort: Int
    /// The protocol (e.g., "tcp", "udp").
    public let proto: String
    
    /// Initializes a new port binding.
    /// - Parameters:
    ///   - containerPort: The port number inside the container.
    ///   - hostPort: The port number on the host.
    ///   - proto: The protocol, defaults to "tcp".
    public init(containerPort: Int, hostPort: Int, proto: String = "tcp") {
        self.containerPort = containerPort
        self.hostPort = hostPort
        self.proto = proto
    }
}

// MARK: - Errors

/// Errors that can occur when using Testcontainers.
public enum TestcontainersError: LocalizedError {
    /// Docker is not available or not running.
    case dockerNotAvailable
    /// The specified Docker image is invalid.
    case invalidImage
    /// The container with the given ID was not found.
    case containerNotFound(String)
    /// The container failed to start or operate.
    case containerFailed(String)
    /// Port mapping failed for the specified port.
    case portMappingFailed(Int)
    /// The wait strategy failed.
    case waitStrategyFailed(String)
    /// A network-related error occurred.
    case networkError(String)
    /// The configuration is invalid.
    case invalidConfiguration(String)
    /// An error occurred in the Docker API.
    case apiError(String)
    /// An operation timed out.
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .dockerNotAvailable:
            return "Docker is not available"
        case .invalidImage:
            return "Invalid Docker image"
        case let .containerNotFound(id):
            return "Container not found: \(id)"
        case let .containerFailed(msg):
            return "Container failed: \(msg)"
        case let .portMappingFailed(port):
            return "Port mapping failed for port \(port)"
        case let .waitStrategyFailed(msg):
            return "Wait strategy failed: \(msg)"
        case let .networkError(msg):
            return "Network error: \(msg)"
        case let .invalidConfiguration(msg):
            return "Invalid configuration: \(msg)"
        case let .apiError(msg):
            return "Docker API error: \(msg)"
        case .timeout:
            return "Operation timed out"
        }
    }
}
