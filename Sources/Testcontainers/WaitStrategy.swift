import Foundation
#if os(Linux)
import FoundationNetworking
#endif

// MARK: - Wait Strategy Protocol

/// A protocol for defining strategies to wait for a container to be ready.
public protocol WaitStrategy {
    /// Waits until the container is ready according to the strategy's criteria.
    /// - Parameters:
    ///   - container: The container to wait for.
    ///   - client: The Docker client.
    /// - Throws: An error if the wait times out or fails.
    func waitUntilReady(container: Container, client: DockerClient) async throws
}

// MARK: - Wait Strategies

/// A wait strategy that performs no waiting.
public struct NoWaitStrategy: WaitStrategy {
    /// Initializes a new no-wait strategy.
    public init() {}

    /// Does nothing, as no waiting is required.
    /// - Parameters:
    ///   - container: The container (ignored).
    ///   - client: The Docker client (ignored).
    public func waitUntilReady(container: Container, client: DockerClient) async throws {
        // No waiting
    }
}

/// A wait strategy that waits for an HTTP endpoint to be available.
public struct HttpWaitStrategy: WaitStrategy {
    /// The port to check for HTTP availability.
    public let port: Int
    /// The path to request.
    public let path: String
    /// The scheme (http or https).
    public let scheme: String
    /// The maximum time to wait.
    public let timeout: TimeInterval
    /// The number of retries.
    public let retries: Int
    
    /// Initializes a new HTTP wait strategy.
    /// - Parameters:
    ///   - port: The port to check.
    ///   - path: The path to request, defaults to "/".
    ///   - scheme: The scheme, defaults to "http".
    ///   - timeout: The timeout in seconds, defaults to 60.
    ///   - retries: The number of retries, defaults to 5.
    public init(
        port: Int,
        path: String = "/",
        scheme: String = "http",
        timeout: TimeInterval = 60,
        retries: Int = 5
    ) {
        self.port = port
        self.path = path
        self.scheme = scheme
        self.timeout = timeout
        self.retries = retries
    }
    
    /// Waits until the HTTP endpoint returns a successful response.
    /// - Parameters:
    ///   - container: The container to wait for.
    ///   - client: The Docker client.
    /// - Throws: An error if the wait times out or fails.
    public func waitUntilReady(container: Container, client: DockerClient) async throws {
        let startTime = Date()
        var lastError: Error?
        
        for _ in 0..<retries {
            if Date().timeIntervalSince(startTime) > timeout {
                throw TestcontainersError.timeout
            }
            
            do {
                guard let host = container.ipAddress ?? container.host else {
                    throw TestcontainersError.invalidConfiguration("No host available")
                }
                
                let mappedPort = try container.getMappedPort(port)
                let urlString = "\(scheme)://\(host):\(mappedPort)\(path)"
                
                guard let url = URL(string: urlString) else {
                    throw TestcontainersError.invalidConfiguration("Invalid URL: \(urlString)")
                }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 5
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
                    return
                }
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                continue
            }
        }
        
        throw lastError ?? TestcontainersError.waitStrategyFailed("HTTP endpoint not available on port \(port)")
    }
}

/// A wait strategy that waits for a TCP port to be available.
public struct TcpWaitStrategy: WaitStrategy {
    /// The port to check for TCP availability.
    public let port: Int
    /// The maximum time to wait.
    public let timeout: TimeInterval
    /// The number of retries.
    public let retries: Int
    
    /// Initializes a new TCP wait strategy.
    /// - Parameters:
    ///   - port: The port to check.
    ///   - timeout: The timeout in seconds, defaults to 60.
    ///   - retries: The number of retries, defaults to 5.
    public init(port: Int, timeout: TimeInterval = 60, retries: Int = 5) {
        self.port = port
        self.timeout = timeout
        self.retries = retries
    }
    
    /// Waits until the TCP port is available.
    /// - Parameters:
    ///   - container: The container to wait for.
    ///   - client: The Docker client.
    /// - Throws: An error if the wait times out or fails.
    public func waitUntilReady(container: Container, client: DockerClient) async throws {
        let startTime = Date()
        
        for _ in 0..<retries {
            if Date().timeIntervalSince(startTime) > timeout {
                throw TestcontainersError.timeout
            }
            
            do {
                guard let host = container.ipAddress ?? container.host else {
                    throw TestcontainersError.invalidConfiguration("No host available")
                }
                
                let mappedPort = try container.getMappedPort(port)
                try await checkTcpConnection(host: host, port: mappedPort, timeout: 5)
                return
            } catch {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                continue
            }
        }
        
        throw TestcontainersError.waitStrategyFailed("TCP port \(port) not available")
    }
    
    private func checkTcpConnection(host: String, port: Int, timeout: TimeInterval) async throws {
        // Simplified TCP check using URLSession
        let urlString = "http://\(host):\(port)"
        guard let url = URL(string: urlString) else {
            throw TestcontainersError.invalidConfiguration("Invalid host/port")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        
        _ = try await URLSession.shared.data(for: request)
    }
}

/// A wait strategy that waits for a specific message in the container logs.
public struct LogWaitStrategy: WaitStrategy {
    /// The message to look for in the logs.
    public let message: String
    /// The maximum time to wait.
    public let timeout: TimeInterval
    
    /// Initializes a new log wait strategy.
    /// - Parameters:
    ///   - message: The message to look for.
    ///   - timeout: The timeout in seconds, defaults to 60.
    public init(message: String, timeout: TimeInterval = 60) {
        self.message = message
        self.timeout = timeout
    }
    
    /// Waits until the specified message appears in the container logs.
    /// - Parameters:
    ///   - container: The container to wait for.
    ///   - client: The Docker client.
    /// - Throws: An error if the wait times out or fails.
    public func waitUntilReady(container: Container, client: DockerClient) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            let logs = try await client.getContainerLogs(containerId: container.id)
            
            if logs.contains(message) {
                return
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }
        
        throw TestcontainersError.waitStrategyFailed("Log message not found: \(message)")
    }
}

/// A wait strategy that waits for a command to succeed inside the container.
public struct ExecWaitStrategy: WaitStrategy {
    /// The command to execute.
    public let command: [String]
    /// The maximum time to wait.
    public let timeout: TimeInterval
    
    /// Initializes a new exec wait strategy.
    /// - Parameters:
    ///   - command: The command to execute.
    ///   - timeout: The timeout in seconds, defaults to 60.
    public init(command: [String], timeout: TimeInterval = 60) {
        self.command = command
        self.timeout = timeout
    }
    
    /// Waits until the command executes successfully inside the container.
    /// - Parameters:
    ///   - container: The container to wait for.
    ///   - client: The Docker client.
    /// - Throws: An error if the wait times out or fails.
    public func waitUntilReady(container: Container, client: DockerClient) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let exec = try await client.execCreate(
                    containerId: container.id,
                    cmd: command
                )
                let output = try await client.execStart(execId: exec.id)
                
                if !output.isEmpty {
                    return
                }
            } catch {
                // Continue trying
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }
        
        throw TestcontainersError.waitStrategyFailed("Exec command failed: \(command.joined(separator: " "))")
    }
}

/// A wait strategy that waits for the container's health check to pass.
public struct HealthCheckWaitStrategy: WaitStrategy {
    /// The maximum time to wait.
    public let timeout: TimeInterval
    
    /// Initializes a new health check wait strategy.
    /// - Parameter timeout: The timeout in seconds, defaults to 60.
    public init(timeout: TimeInterval = 60) {
        self.timeout = timeout
    }
    
    /// Waits until the container's health check status is "healthy".
    /// - Parameters:
    ///   - container: The container to wait for.
    ///   - client: The Docker client.
    /// - Throws: An error if the wait times out or fails.
    public func waitUntilReady(container: Container, client: DockerClient) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            let inspect = try await client.inspectContainer(id: container.id)
            
            if inspect.state.status.lowercased() == "healthy" {
                return
            }
            
            if inspect.state.status.lowercased() == "unhealthy" {
                throw TestcontainersError.waitStrategyFailed("Container is unhealthy")
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }
        
        throw TestcontainersError.timeout
    }
}

/// A wait strategy that combines multiple wait strategies.
public struct CombinedWaitStrategy: WaitStrategy {
    /// The strategies to combine.
    public let strategies: [WaitStrategy]
    
    /// Initializes a new combined wait strategy.
    /// - Parameter strategies: The wait strategies to combine.
    public init(_ strategies: [WaitStrategy]) {
        self.strategies = strategies
    }
    
    /// Waits until all combined strategies are ready.
    /// - Parameters:
    ///   - container: The container to wait for.
    ///   - client: The Docker client.
    /// - Throws: An error if any strategy fails.
    public func waitUntilReady(container: Container, client: DockerClient) async throws {
        for strategy in strategies {
            try await strategy.waitUntilReady(container: container, client: client)
        }
    }
}

// MARK: - Wait Strategy Builder

/// A utility class for creating wait strategies with a fluent API.
public class Wait {
    /// Creates a no-wait strategy.
    /// - Returns: A wait strategy that performs no waiting.
    public static func noWait() -> WaitStrategy {
        NoWaitStrategy()
    }
    
    /// Creates an HTTP wait strategy.
    /// - Parameters:
    ///   - port: The port to check.
    ///   - path: The path to request, defaults to "/".
    ///   - scheme: The scheme, defaults to "http".
    ///   - timeout: The timeout in seconds, defaults to 60.
    /// - Returns: An HTTP wait strategy.
    public static func http(
        port: Int,
        path: String = "/",
        scheme: String = "http",
        timeout: TimeInterval = 60
    ) -> WaitStrategy {
        HttpWaitStrategy(port: port, path: path, scheme: scheme, timeout: timeout)
    }
    
    /// Creates a TCP wait strategy.
    /// - Parameters:
    ///   - port: The port to check.
    ///   - timeout: The timeout in seconds, defaults to 60.
    /// - Returns: A TCP wait strategy.
    public static func tcp(port: Int, timeout: TimeInterval = 60) -> WaitStrategy {
        TcpWaitStrategy(port: port, timeout: timeout)
    }
    
    /// Creates a log wait strategy.
    /// - Parameters:
    ///   - message: The message to look for.
    ///   - timeout: The timeout in seconds, defaults to 60.
    /// - Returns: A log wait strategy.
    public static func log(message: String, timeout: TimeInterval = 60) -> WaitStrategy {
        LogWaitStrategy(message: message, timeout: timeout)
    }
    
    /// Creates an exec wait strategy.
    /// - Parameters:
    ///   - command: The command to execute.
    ///   - timeout: The timeout in seconds, defaults to 60.
    /// - Returns: An exec wait strategy.
    public static func exec(command: [String], timeout: TimeInterval = 60) -> WaitStrategy {
        ExecWaitStrategy(command: command, timeout: timeout)
    }
    
    /// Creates a health check wait strategy.
    /// - Parameter timeout: The timeout in seconds, defaults to 60.
    /// - Returns: A health check wait strategy.
    public static func healthCheck(timeout: TimeInterval = 60) -> WaitStrategy {
        HealthCheckWaitStrategy(timeout: timeout)
    }
    
    /// Creates a combined wait strategy.
    /// - Parameter strategies: The wait strategies to combine.
    /// - Returns: A combined wait strategy.
    public static func all(_ strategies: WaitStrategy...) -> WaitStrategy {
        CombinedWaitStrategy(strategies)
    }
}

// MARK: - Custom Wait Strategy

/// A wait strategy that allows custom logic via a closure.
public struct CustomWaitStrategy: WaitStrategy {
    private let closure: (Container, DockerClient) async throws -> Void
    
    /// Initializes a new custom wait strategy.
    /// - Parameter closure: The closure to execute for waiting.
    public init(closure: @escaping (Container, DockerClient) async throws -> Void) {
        self.closure = closure
    }
    
    /// Executes the custom wait logic.
    /// - Parameters:
    ///   - container: The container to wait for.
    ///   - client: The Docker client.
    /// - Throws: An error if the custom logic fails.
    public func waitUntilReady(container: Container, client: DockerClient) async throws {
        try await closure(container, client)
    }
}
