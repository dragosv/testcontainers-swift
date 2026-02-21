# Creating a Docker image

Testcontainers for Swift pulls Docker images automatically when creating containers via `ContainerBuilder.buildAsync()`. If the image is not available locally, it will be downloaded from the configured registry (Docker Hub by default).

## Automatic image pulling

When you use `ContainerBuilder`, the image is pulled as part of the `buildAsync()` call:

```swift
let container = try await ContainerBuilder("postgres:16")
    .withEnvironment("POSTGRES_PASSWORD", "password")
    .withPortBinding(5432, assignRandomHostPort: true)
    .buildAsync()
```

If the image `postgres:16` is not present locally, Testcontainers will automatically pull it before creating the container.

## Using private registries

If your image is hosted in a private registry, ensure your Docker daemon is authenticated before running tests:

```bash
docker login my-registry.example.com
```

Testcontainers will use the credentials stored by Docker for image pulls.

## Low-level image management

For advanced use cases, you can manage images directly through the `DockerClientSwift` module:

```swift
import DockerClientSwift

let client = DockerClientSwift.DockerClient(daemonSocket: "/var/run/docker.sock")

// Pull an image
try await client.images.pull(byName: "alpine", tag: "latest")

// List images
let images = try await client.images.list()

// Remove an image
try await client.images.remove(name: "alpine:latest")
```

!!! note

    For most testing scenarios, you do not need to manage images directly. `ContainerBuilder.buildAsync()` handles image pulling transparently.
