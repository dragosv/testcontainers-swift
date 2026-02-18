import DockerClientSwift
import Foundation
import NIOHTTP1

// MARK: - Raw Inspect Container Endpoint

/// Endpoint to get detailed container inspection data including port mappings and network settings.
struct RawInspectContainerEndpoint: Endpoint {
    typealias Body = NoBody
    typealias Response = ContainerInspect
    var method: HTTPMethod = .GET

    let nameOrId: String

    var path: String {
        "containers/\(nameOrId)/json"
    }
}

// MARK: - Raw Exec Endpoints

/// Endpoint to create an exec instance in a container.
struct RawExecCreateEndpoint: Endpoint {
    typealias Response = ExecCreateResponse
    typealias Body = ExecCreateBody
    var method: HTTPMethod = .POST
    var body: ExecCreateBody?

    let containerId: String

    init(containerId: String, cmd: [String]) {
        self.containerId = containerId
        self.body = ExecCreateBody(
            Cmd: cmd,
            AttachStdout: true,
            AttachStderr: true
        )
    }

    var path: String {
        "containers/\(containerId)/exec"
    }

    struct ExecCreateBody: Codable {
        let Cmd: [String]
        let AttachStdout: Bool
        let AttachStderr: Bool
    }

    struct ExecCreateResponse: Codable {
        let Id: String
    }
}

/// Endpoint to start an exec instance.
struct RawExecStartEndpoint: PipelineEndpoint {
    typealias Body = ExecStartBody
    typealias Response = String
    var method: HTTPMethod = .POST
    var body: ExecStartBody?

    let execId: String

    init(execId: String) {
        self.execId = execId
        self.body = ExecStartBody(Detach: false, Tty: false)
    }

    var path: String {
        "exec/\(execId)/start"
    }

    struct ExecStartBody: Codable {
        let Detach: Bool
        let Tty: Bool
    }

    func map(data: String) throws -> String {
        data
    }
}

// MARK: - Raw Network Endpoints

/// Endpoint to create a Docker network.
struct RawCreateNetworkEndpoint: Endpoint {
    typealias Response = CreateNetworkResponse
    typealias Body = CreateNetworkBody
    var method: HTTPMethod = .POST
    var body: CreateNetworkBody?

    init(name: String, driver: String) {
        self.body = CreateNetworkBody(Name: name, Driver: driver)
    }

    var path: String {
        "networks/create"
    }

    struct CreateNetworkBody: Codable {
        let Name: String
        let Driver: String
    }

    struct CreateNetworkResponse: Codable {
        let Id: String
    }
}

/// Endpoint to connect a container to a network.
struct RawConnectNetworkEndpoint: Endpoint {
    typealias Response = NoBody?
    typealias Body = ConnectNetworkBody
    var method: HTTPMethod = .POST
    var body: ConnectNetworkBody?

    let networkId: String

    init(networkId: String, containerId: String) {
        self.networkId = networkId
        self.body = ConnectNetworkBody(Container: containerId)
    }

    var path: String {
        "networks/\(networkId)/connect"
    }

    struct ConnectNetworkBody: Codable {
        let Container: String
    }
}

/// Endpoint to disconnect a container from a network.
struct RawDisconnectNetworkEndpoint: Endpoint {
    typealias Response = NoBody?
    typealias Body = DisconnectNetworkBody
    var method: HTTPMethod = .POST
    var body: DisconnectNetworkBody?

    let networkId: String

    init(networkId: String, containerId: String) {
        self.networkId = networkId
        self.body = DisconnectNetworkBody(Container: containerId)
    }

    var path: String {
        "networks/\(networkId)/disconnect"
    }

    struct DisconnectNetworkBody: Codable {
        let Container: String
    }
}

/// Endpoint to remove a Docker network.
struct RawRemoveNetworkEndpoint: Endpoint {
    typealias Response = NoBody?
    typealias Body = NoBody
    var method: HTTPMethod = .DELETE

    let networkId: String

    var path: String {
        "networks/\(networkId)"
    }
}
