# Low-level API access

Testcontainers for Swift is built on top of `DockerClientSwift`, a low-level Docker HTTP client that communicates with the Docker Engine API (v1.44) over a Unix socket. While the high-level `Testcontainers` module is recommended for test scenarios, you can access the Docker client directly for advanced use cases.

## Accessing the Docker client

The `TestcontainersDockerClient` provides a singleton instance with access to the underlying `DockerClientSwift.DockerClient`:

```swift
import Testcontainers

let dockerClient = TestcontainersDockerClient.getInstance()
```

## Container operations

```swift
// Create, start, stop, and remove containers
try await dockerClient.start(id: containerId)
try await dockerClient.stopContainer(id: containerId, timeout: 10)
try await dockerClient.removeContainer(id: containerId, force: true)

// Inspect a container
let inspect = try await dockerClient.inspectContainer(id: containerId)

// Get logs
let logs = try await dockerClient.getContainerLogs(containerId: containerId)

// Execute a command
let exec = try await dockerClient.execCreate(containerId: containerId, cmd: ["echo", "hello"])
let output = try await dockerClient.execStart(execId: exec.id)
```

## Image operations

```swift
// Pull an image
try await dockerClient.pullImage(image: "alpine:latest")
```

## Network operations

```swift
// Create a network
let networkId = try await dockerClient.createNetwork(name: "my-network", driver: "bridge")

// Connect / disconnect containers
try await dockerClient.connectNetwork(networkId: networkId, containerId: containerId)
try await dockerClient.disconnectNetwork(networkId: networkId, containerId: containerId)
```

## Using DockerClientSwift directly

For even lower-level access, import `DockerClientSwift` directly:

```swift
import DockerClientSwift

let client = DockerClientSwift.DockerClient(daemonSocket: "/var/run/docker.sock")

// List containers
let containers = try await client.containers.list()

// List images
let images = try await client.images.list()
```

!!! warning

    The low-level API is not covered by the same stability guarantees as the high-level `Testcontainers` module. Method signatures may change between minor versions.

## Docker socket detection

The `TestcontainersDockerClient` automatically detects the Docker socket in this order:

1. `DOCKER_HOST` environment variable
2. `/var/run/docker.sock`
3. `~/.docker/run/docker.sock` (Docker Desktop on macOS)

See [Custom Configuration](configuration.md) for more details on Docker host detection.
