# System Requirements

This page describes the prerequisites for using Testcontainers for Swift.

## Swift

| Requirement | Minimum Version |
|-------------|:---------------:|
| Swift       | 6.1             |
| macOS       | 13.0+           |
| Linux       | Ubuntu 22.04+   |

Testcontainers for Swift is distributed as a Swift Package Manager package. It uses `async/await` concurrency throughout, requiring the Swift 6.1 toolchain or later.

## Docker

A Docker-compatible container runtime must be installed and running. Testcontainers for Swift communicates with the Docker Engine API over a Unix socket.

### Supported runtimes

| Runtime         | Supported | Notes                              |
|-----------------|:---------:|------------------------------------|
| Docker Desktop  | Yes       | macOS and Linux                    |
| Docker Engine   | Yes       | Linux                              |
| Colima          | Yes       | macOS, set `DOCKER_HOST` manually  |
| Podman          | Untested  | May work with Docker-compatible socket |
| Rancher Desktop | Untested  | May work with Docker-compatible socket |

### Docker socket detection

Testcontainers for Swift looks for the Docker socket in this order:

1. `DOCKER_HOST` environment variable
2. `/var/run/docker.sock`
3. `~/.docker/run/docker.sock`

If your Docker runtime uses a non-standard socket path, set `DOCKER_HOST`:

```bash
export DOCKER_HOST=unix:///Users/$USER/.colima/default/docker.sock
```

### Docker Engine API

Testcontainers for Swift targets Docker Engine API **v1.44**. Ensure your Docker runtime supports this API version by running:

```bash
docker version --format '{{.Server.APIVersion}}'
```

## Network access

Container images are pulled from Docker Hub by default. Your environment must have network access to the registries hosting your desired images, or you must pre-pull images before running tests.

## CI Environments

Testcontainers for Swift works in any CI environment that provides Docker access. See the following guides:

- [GitHub Actions](ci/github_actions.md)
- [GitLab CI/CD](ci/gitlab_ci.md)
- [Docker-in-Docker Patterns](ci/dind_patterns.md)
