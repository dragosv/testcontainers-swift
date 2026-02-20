# Custom configuration

You can override some default properties if your environment requires it.

## Docker host detection

Testcontainers for Swift will attempt to detect the Docker environment and configure everything to work automatically.

However, sometimes customization is required. Testcontainers for Swift will respect the following order:

1. **`DOCKER_HOST` environment variable** — If set, this takes priority. The value must use the `unix://` scheme (e.g., `unix:///var/run/docker.sock`). TCP connections are also supported (e.g., `tcp://localhost:2375`).
2. **`/var/run/docker.sock`** — Standard Docker socket on macOS and Linux.
3. **`~/.docker/run/docker.sock`** — Docker Desktop default on macOS.

If none of the above are found, the library defaults to `/var/run/docker.sock`.

## Environment variables

| Variable       | Description                                                           | Example                              |
|----------------|-----------------------------------------------------------------------|--------------------------------------|
| `DOCKER_HOST`  | Override the Docker daemon socket or TCP address.                     | `unix:///var/run/docker.sock`        |

Set it before running tests:

```bash
export DOCKER_HOST=unix:///var/run/docker.sock
swift test
```

Or set it in your CI configuration:

```yaml
env:
  DOCKER_HOST: tcp://docker:2375
```

## Docker socket path detection

Testcontainers for Swift will attempt to detect the Docker socket path and configure everything to work automatically.

The following locations are checked in order:

| Priority | Location                             | Notes                                       |
|:--------:|--------------------------------------|---------------------------------------------|
| 1        | `DOCKER_HOST` env var                | Parsed from `unix://` prefix                |
| 2        | `/var/run/docker.sock`               | Standard path on macOS and Linux             |
| 3        | `~/.docker/run/docker.sock`          | Docker Desktop on macOS                      |

## Programmatic configuration

You can initialize the Docker client with a custom socket path:

```swift
import Testcontainers

// Use default auto-detection
let client = TestcontainersDockerClient.getInstance()

// Or specify a custom socket path
let customClient = TestcontainersDockerClient(socketPath: "/custom/docker.sock")
```

## Logging

Testcontainers for Swift uses [swift-log](https://github.com/apple/swift-log) for diagnostic output. Configure the log level to troubleshoot container issues:

```swift
import Logging

var logger = Logger(label: "testcontainers")
logger.logLevel = .debug
```

Log levels:

| Level     | Description                                   |
|-----------|-----------------------------------------------|
| `.trace`  | Very detailed diagnostic information.         |
| `.debug`  | Detailed information for debugging.           |
| `.info`   | General operational messages (default).        |
| `.warning`| Potential issues that may need attention.      |
| `.error`  | Errors that prevent normal operation.          |

## Platform requirements

| Requirement     | Minimum version      |
|-----------------|----------------------|
| Swift           | 6.1                  |
| macOS           | 13.0 (Ventura)       |
| Linux           | Ubuntu 22.04+        |
| Docker          | 20.10+               |
| Docker API      | v1.44                |
