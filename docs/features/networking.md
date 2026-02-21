# Networking and communicating with containers

There are two common cases for setting up communication with containers.

## Exposing ports to the host

The simplest case does not require additional network configuration. The host running the test connects directly to the container through a mapped port.

### Exposing container ports

Use `withPortBinding(_:assignRandomHostPort:)` to expose a container port to a random host port:

```swift
let container = try await ContainerBuilder("postgres:16")
    .withEnvironment("POSTGRES_PASSWORD", "password")
    .withPortBinding(5432, assignRandomHostPort: true)
    .buildAsync()

try await container.start()
```

When you use `withPortBinding` with `assignRandomHostPort: true`, you should think of it as `docker run -p <port>`. Docker maps the container port to a random available port on your host.

This is important for parallelization: if you run multiple tests in parallel, each can start its own container — and each will be exposed on a different random port, avoiding conflicts.

### Getting the container host

Resolve the container address from the running container:

```swift
let host = container.host ?? "localhost"
```

!!! warning

    Do not hardcode `localhost`, `127.0.0.1`, or any other fixed address to access the container. The address may vary depending on the Docker environment (e.g., Docker Desktop, remote Docker host, CI environments).

### Getting the mapped port

Retrieve the random host port assigned by Docker:

```swift
let port = try container.getMappedPort(5432)
```

### Complete example

```swift
let container = try await ContainerBuilder("postgres:16")
    .withEnvironment("POSTGRES_PASSWORD", "password")
    .withPortBinding(5432, assignRandomHostPort: true)
    .withWaitStrategy(Wait.log(message: "database system is ready"))
    .buildAsync()

try await container.start()
defer { Task { try? await container.stop(timeout: 10) } }

let host = container.host ?? "localhost"
let port = try container.getMappedPort(5432)
// Connect to postgres at host:port
```

## Creating networks

For container-to-container communication, create a custom Docker network. Containers on the same network can communicate using network aliases without exposing ports through the host.

### Creating a network

Use `NetworkBuilder` to create a Docker network:

```swift
let network = try await NetworkBuilder("my-network")
    .withDriver("bridge")
    .build()
```

#### Network options

| Builder method         | Description                                                         |
|------------------------|---------------------------------------------------------------------|
| `NetworkBuilder(_:)`   | Creates a new network builder with the given name.                  |
| `withDriver(_:)`       | Sets the network driver (default: `"bridge"`).                      |
| `withInternal(_:)`     | Sets whether the network is internal (isolated from external).      |
| `build()`              | Creates the network in Docker and returns a `DockerNetworkImpl`.    |

### Connecting containers to a network

Assign a network to a container using `withNetwork(_:)` on the builder:

```swift
let container = try await ContainerBuilder("postgres:16")
    .withNetwork(network)
    .withNetworkAliases(["db", "postgres"])
    .buildAsync()
```

You can also connect an already-running container to a network:

```swift
try await network.connectContainer(id: container.id)
```

### Network instance methods

| Method                        | Description                                      |
|-------------------------------|--------------------------------------------------|
| `connectContainer(id:)`       | Connects a container to this network.            |
| `disconnectContainer(id:)`    | Disconnects a container from this network.       |

## Advanced networking

### Multi-container networking with aliases

The following example creates a network and assigns multiple containers. The containers communicate using network aliases:

```swift
// Create a custom network
let network = try await NetworkBuilder("app-network")
    .withDriver("bridge")
    .build()

// Create a PostgreSQL container on the network
let postgres = try await ContainerBuilder("postgres:16")
    .withName("postgres-service")
    .withEnvironment("POSTGRES_PASSWORD", "password")
    .withPortBinding(5432, assignRandomHostPort: true)
    .withWaitStrategy(Wait.log(message: "database system is ready"))
    .withNetwork(network)
    .withNetworkAliases(["postgres"])
    .buildAsync()

try await postgres.start()

// Create an application container on the same network
let app = try await ContainerBuilder("alpine:latest")
    .withEntrypoint(["top"])
    .withNetwork(network)
    .buildAsync()

try await app.start()

// The app container can reach PostgreSQL using hostname "postgres"
let output = try await app.exec(command: ["nc", "-z", "postgres", "5432"])
```

!!! tip

    When containers are on the same Docker network, they can communicate using network aliases directly — no port mapping to the host is needed. Use the container port (for example, `5432`), not the mapped host port.
