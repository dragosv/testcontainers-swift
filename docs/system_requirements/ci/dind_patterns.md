# Docker-in-Docker Patterns

Running Testcontainers inside a Docker container (e.g., for CI pipelines) requires access to a Docker daemon. There are two common approaches.

## Docker socket mounting (recommended)

Mount the host's Docker socket into the build container. This is the simplest and fastest approach:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  -w /workspace \
  swift:6.1 \
  swift test
```

With Docker Compose:

```yaml
services:
  tests:
    image: swift:6.1
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - .:/workspace
    working_dir: /workspace
    command: swift test
```

!!! warning

    Mounting the Docker socket gives the build container full access to the host's Docker daemon. This is the "Docker wormhole" pattern — containers created by Testcontainers are **siblings**, not children, of the build container.

### Advantages

- No additional Docker daemon overhead
- Images cached on the host are reused
- Faster container startup

### Limitations

- No isolation between the build and host Docker
- Port mappings are from the host perspective
- Requires trust in the build container

## Docker-in-Docker (DinD)

Run a full Docker daemon inside the CI container. This provides better isolation but is more complex:

```yaml
# GitLab CI example
test:
  image: swift:6.1
  services:
    - docker:dind
  variables:
    DOCKER_HOST: tcp://docker:2375
    DOCKER_TLS_CERTDIR: ""
  script:
    - swift build
    - swift test
```

### Advantages

- Full isolation from the host Docker daemon
- Each job starts with a clean Docker state
- Better security boundaries

### Limitations

- No image caching between jobs (clean daemon each time)
- Additional overhead for running a nested Docker daemon
- More complex networking setup

## Networking considerations

When using the Docker socket mounting pattern, containers created by Testcontainers run on the **host's** Docker daemon:

- Port mappings are from the **host** perspective
- Container-to-container networking uses the host Docker network
- The build container accesses Testcontainers-created containers via `localhost` (or the mapped host port)

When using DinD:

- The Docker daemon runs inside the `docker:dind` service
- Set `DOCKER_HOST` to point to the DinD service (e.g., `tcp://docker:2375`)
- Containers are isolated within the DinD environment

## Setting `DOCKER_HOST`

If your Docker socket is at a non-standard path, set the `DOCKER_HOST` environment variable:

```bash
# Unix socket
export DOCKER_HOST=unix:///var/run/docker.sock

# TCP (for DinD)
export DOCKER_HOST=tcp://docker:2375

# Colima on macOS
export DOCKER_HOST=unix:///Users/$USER/.colima/default/docker.sock
```

Testcontainers for Swift reads `DOCKER_HOST` as the first step in [socket detection](../index.md).
