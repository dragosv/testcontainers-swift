# Testcontainers for Swift

Testcontainers for Swift is a Swift package that makes it simple to create and clean up container-based dependencies for automated integration and end-to-end tests. The library integrates with Apple's XCTest framework and Swift's native `async`/`await` concurrency.

Typical use cases include spinning up throwaway instances of databases, message brokers, or any Docker image as part of your test suite — containers start in seconds and are cleaned up automatically when the test finishes.

```swift title="Quickstart example"
import Testcontainers

let container = try await ContainerBuilder("testcontainers/helloworld:1.3.0")
    .withPortBinding(8080, assignRandomHostPort: true)
    .withWaitStrategy(Wait.http(port: 8080, path: "/uuid"))
    .buildAsync()

try await container.start()
defer { Task { try? await container.stop(timeout: 10) } }

let port = try container.getMappedPort(8080)
let host = container.host ?? "localhost"

let url = URL(string: "http://\(host):\(port)/uuid")!
let (data, _) = try await URLSession.shared.data(from: url)
print("Received UUID: \(String(data: data, encoding: .utf8)!)")
```

<p style="text-align:center">
  <strong>Not using Swift? Here are other supported languages!</strong>
</p>
<div class="card-grid">
  <a class="card-grid-item" href="https://java.testcontainers.org">
    <img src="language-logos/java.svg" />Java
  </a>
  <a class="card-grid-item" href="https://golang.testcontainers.org">
    <img src="language-logos/go.svg" />Go
  </a>
  <a class="card-grid-item" href="https://dotnet.testcontainers.org">
    <img src="language-logos/dotnet.svg" />.NET
  </a>
  <a class="card-grid-item" href="https://node.testcontainers.org">
    <img src="language-logos/nodejs.svg" />Node.js
  </a>
  <a class="card-grid-item" href="https://testcontainers-python.readthedocs.io/en/latest/">
    <img src="language-logos/python.svg" />Python
  </a>
  <a class="card-grid-item" href="https://docs.rs/testcontainers/latest/testcontainers/">
    <img src="language-logos/rust.svg" />Rust
  </a>
  <a class="card-grid-item" href="https://github.com/testcontainers/testcontainers-hs/">
    <img src="language-logos/haskell.svg"/>Haskell
  </a>
  <a href="https://github.com/testcontainers/testcontainers-ruby/" class="card-grid-item"><img src="language-logos/ruby.svg"/>Ruby</a>
</div>

## About

Testcontainers for Swift is a Swift package to support tests with throwaway instances of Docker containers. Built on Swift 6.1 with `async`/`await` concurrency, it communicates with Docker via the Docker Remote API over Unix sockets and provides a lightweight, type-safe implementation to support your test environment.

Choose from existing pre-configured [modules](modules/index.md) — PostgreSQL, MySQL, Redis, and MongoDB — and start containers within seconds. Or use the generic `ContainerBuilder` to run any Docker image with full control over configuration.

Read the [Quickstart](quickstart/index.md) to get up and running in minutes.

## System requirements

Please read the [System Requirements](system_requirements/index.md) page before you start.

| Requirement     | Minimum version      |
|-----------------|----------------------|
| Swift           | 6.1                  |
| macOS           | 13.0 (Ventura)       |
| Linux           | Ubuntu 22.04+        |
| Docker          | 20.10+               |

Testcontainers automatically detects the Docker socket. It checks the `DOCKER_HOST` environment variable first, then `~/.docker/run/docker.sock` (Docker Desktop on macOS), and finally `/var/run/docker.sock`.

## License

See [LICENSE](https://github.com/dragosv/testcontainers-swift/blob/main/LICENSE).

## Copyright

Copyright (c) 2024 - 2026 The Testcontainers for Swift Authors.

----

Join our [Slack workspace](https://slack.testcontainers.org/) | [Testcontainers OSS](https://www.testcontainers.org/) | [Testcontainers Cloud](https://testcontainers.com/cloud/)
[testcontainers-cloud]: https://www.testcontainers.cloud/
