# How to create a container

Testcontainers' generic container support offers the greatest flexibility and makes it easy to use virtually any container image in the context of a temporary test environment. To interact or exchange data with a container, Testcontainers provides `ContainerBuilder` to configure and create the resource.

## ContainerBuilder

The `ContainerBuilder` is the primary entrypoint for creating containers. It receives the Docker image name and provides a fluent API for configuration:

```swift
let container = try await ContainerBuilder("redis:7")
    .withPortBinding(6379, assignRandomHostPort: true)
    .withWaitStrategy(Wait.log(message: "Ready to accept connections"))
    .buildAsync()

try await container.start()
defer { Task { try? await container.stop(timeout: 10) } }
```

The `buildAsync()` method pulls the image (if needed) and creates the container in Docker. The `start()` method starts the container and the configured wait strategy runs to verify readiness.

## Container options

When creating a container, you can pass options to `ContainerBuilder` to configure it. The options are organized into functional categories.

### Basic options

#### withPortBinding

Exposes a container port to the host. Use `assignRandomHostPort: true` to let Docker assign a random available host port — this is the recommended approach to avoid port conflicts.

```swift
// Random host port (recommended)
.withPortBinding(8080, assignRandomHostPort: true)

// Specific host port
.withPortBinding(hostPort: 8080, containerPort: 80)
```

After starting the container, retrieve the mapped port:

```swift
let mappedPort = try container.getMappedPort(8080)
```

#### withEnvironment

Sets environment variables for the container.

```swift
// Single variable
.withEnvironment("POSTGRES_PASSWORD", "secret")

// Multiple variables from a dictionary
.withEnvironment([
    "POSTGRES_DB": "mydb",
    "POSTGRES_USER": "admin"
])
```

#### withWaitStrategy

Sets the [wait strategy](wait/introduction.md) to determine when the container is ready for use.

```swift
.withWaitStrategy(Wait.http(port: 8080, path: "/health"))
```

#### withEntrypoint

Specifies or overrides the container's `ENTRYPOINT`:

```swift
.withEntrypoint(["nginx", "-g", "daemon off;"])
```

#### withCmd

Specifies or overrides the container's `CMD`:

```swift
.withCmd(["--config", "/etc/app.conf"])
```

#### withLabel

Applies Docker labels to the container:

```swift
// Single label
.withLabel("team", "backend")

// Multiple labels from a dictionary
.withLabel(["app": "myservice", "env": "test"])
```

### Networking options

#### withNetwork

Assigns a Docker network to the container. See [Networking](networking.md) for details.

```swift
let network = try await NetworkBuilder("my-network").build()
let container = try await ContainerBuilder("postgres:16")
    .withNetwork(network)
    .buildAsync()
```

#### withNetworkAliases

Assigns network-scoped aliases so other containers on the same network can reach this container by name:

```swift
.withNetworkAliases(["db", "postgres"])
```

### Container name

#### withName

Sets the container name:

```swift
.withName("my-postgres")
```

## Container methods

After building and starting a container, the `Container` protocol exposes several useful methods.

### Getting the mapped port

```swift
let port = try container.getMappedPort(5432)
```

### Getting the host

```swift
let host = container.host ?? "localhost"
```

### Executing commands

Execute a command inside the running container and get the output:

```swift
let output = try await container.exec(command: ["echo", "Hello from container"])
print(output) // "Hello from container"
```

### Getting logs

Retrieve the container's stdout/stderr logs:

```swift
let logs = try await container.getLogs()
print(logs)
```

### Getting container state

```swift
let state = try await container.getState()
// Returns: .running, .exited, .paused, .created, .restarting, .dead, or .unknown
```

### Stopping and deleting

```swift
// Stop the container (with timeout in seconds)
try await container.stop(timeout: 10)

// Force-remove the container
try await container.delete()
```

## Lifecycle

A typical container lifecycle in a test looks like this:

```
ContainerBuilder("image:tag")  →  .buildAsync()  →  .start()  →  test logic  →  .stop()
      configure                    pull & create      start         use          cleanup
```

The recommended cleanup pattern uses `defer`:

```swift
let container = try await ContainerBuilder("postgres:16")
    .withEnvironment("POSTGRES_PASSWORD", "password")
    .withPortBinding(5432, assignRandomHostPort: true)
    .withWaitStrategy(Wait.log(message: "database system is ready to accept connections"))
    .buildAsync()

try await container.start()
defer { Task { try? await container.stop(timeout: 10) } }

// Test logic using the container...
```

## Examples

### NGINX container

```swift
let container = try await ContainerBuilder("nginx:1.26.3-alpine3.20")
    .withName("my-nginx")
    .withPortBinding(80, assignRandomHostPort: true)
    .withWaitStrategy(Wait.http(port: 80))
    .buildAsync()

try await container.start()
defer { Task { try? await container.stop(timeout: 10) } }

let port = try container.getMappedPort(80)
let host = container.host ?? "localhost"

let url = URL(string: "http://\(host):\(port)")!
let (_, response) = try await URLSession.shared.data(from: url)
let httpResponse = response as! HTTPURLResponse
assert(httpResponse.statusCode == 200)
```

### Container with command output

```swift
let container = try await ContainerBuilder("alpine:latest")
    .withCmd(["sh", "-c", "echo 'Hello from container' && sleep 10"])
    .buildAsync()

try await container.start()
defer { Task { try? await container.stop(timeout: 10) } }

try await Task.sleep(nanoseconds: 2_000_000_000)
let logs = try await container.getLogs()
print(logs) // "Hello from container\n"
```

## Supported commands

| Builder method                             | Description                                                                   |
|--------------------------------------------|-------------------------------------------------------------------------------|
| `withName(_:)`                             | Sets the container name.                                                      |
| `withEnvironment(_:_:)`                    | Sets a single environment variable.                                           |
| `withEnvironment(_:)` (dictionary)         | Sets multiple environment variables from a dictionary.                        |
| `withLabel(_:_:)`                          | Applies a single label to the container.                                      |
| `withLabel(_:)` (dictionary)               | Applies multiple labels from a dictionary.                                    |
| `withPortBinding(_:assignRandomHostPort:)` | Publishes a container port, optionally to a random host port.                 |
| `withPortBinding(hostPort:containerPort:)` | Publishes a container port to a specific host port.                           |
| `withEntrypoint(_:)`                       | Specifies or overrides the `ENTRYPOINT`.                                      |
| `withCmd(_:)`                              | Specifies or overrides the `CMD`.                                             |
| `withWaitStrategy(_:)`                     | Sets the wait strategy to indicate when the container is ready.               |
| `withNetwork(_:)`                          | Assigns a Docker network to the container.                                    |
| `withNetworkAliases(_:)`                   | Assigns network-scoped aliases to the container.                              |
| `build()`                                  | Builds a container instance (local only, does not create in Docker).          |
| `buildAsync()`                             | Builds and creates the container in Docker (pulls image, creates container).  |

!!! tip

    Testcontainers for Swift detects your Docker host configuration automatically. You do **not** need to set the Docker daemon socket manually.
