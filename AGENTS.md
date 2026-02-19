# AGENTS.md

Guidelines for AI agents working in the **testcontainers-swift** repository.

## Project Overview

Swift library for managing throwaway Docker containers in tests, inspired by [testcontainers-dotnet](https://github.com/testcontainers/testcontainers-dotnet). Two modules: `DockerClientSwift` (low-level Docker HTTP client) and `Testcontainers` (high-level API with builders, wait strategies, and pre-configured modules).

See [ARCHITECTURE.md](ARCHITECTURE.md) for design decisions and component diagrams.
See [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) for a full feature inventory.

## Build & Test

```bash
swift build          # Build all targets
swift test           # Run the full test suite (requires Docker running)
```

Formatting (do **not** modify `.swiftformat.json`):

```bash
/opt/homebrew/bin/swiftformat --lint .   # Check formatting
/opt/homebrew/bin/swiftformat .          # Auto-fix formatting
```

## Code Style

- Swift 6.1, Swift Package Manager, async/await concurrency.
- 4-space indentation, ~120-character line limit.
- `PascalCase` for types, `camelCase` for everything else.
- All public APIs must have `///` doc comments.
- Use `@discardableResult` on builder methods that return `Self`.
- Use `async throws` for any I/O. Never use callbacks or Combine.
- Mark thread-safe reference types `@unchecked Sendable`.
- Follow the rules in [CONTRIBUTING.md](CONTRIBUTING.md) for commit messages and PR conventions.

## Architecture Rules

- **Module boundary is strict**: `Testcontainers` depends on `DockerClientSwift`, never the reverse. `DockerClientSwift` must not reference test-container concepts.
- **Protocols over base classes**: `Container` and `WaitStrategy` are protocols.
- **Builder → Reference two-phase pattern** for modules: the builder type (e.g. `PostgresContainer`) configures; `.start()` returns a reference type (e.g. `PostgresContainerReference`) that exposes runtime helpers like `getConnectionString()`.
- **Strategy pattern for readiness**: all wait strategies implement `WaitStrategy` and are composable via `CombinedWaitStrategy`.

See [ARCHITECTURE.md](ARCHITECTURE.md) for diagrams and rationale.

## Key Paths

| Area | Path |
|------|------|
| Package manifest | `Package.swift` |
| High-level API | `Sources/Testcontainers/` |
| Docker HTTP client | `Sources/DockerClientSwift/` |
| Pre-configured modules | `Sources/Testcontainers/Modules.swift` |
| Wait strategies | `Sources/Testcontainers/WaitStrategy.swift` |
| Container protocol & builder | `Sources/Testcontainers/Container.swift` |
| Tests | `Tests/TestcontainersTests.swift` |
| Examples | `Examples/main.swift` |
| CI workflows | `.github/workflows/` |

## Common Agent Tasks

### Adding a new container module

1. Add the builder class and reference class in `Sources/Testcontainers/Modules.swift`, following the existing `PostgresContainer` / `PostgresContainerReference` pattern.
2. Pre-configure: image, default port, environment variables, and a wait strategy.
3. Expose a `getConnectionString()` (or equivalent) on the reference type.
4. Add tests in `Tests/TestcontainersTests.swift`.
5. Update `Examples/main.swift` with a usage example.

### Adding a new wait strategy

1. Create a struct conforming to `WaitStrategy` in `Sources/Testcontainers/WaitStrategy.swift`.
2. Implement `waitUntilReady(container:client:)` with timeout + retry loop.
3. Add a static convenience method on the `Wait` class.
4. Add a test exercising the new strategy.

### Updating CI/CD

Workflow files live in `.github/workflows/`. Coverage uploads use Codecov. See `codecov.yml` for thresholds.

## Testing Expectations

- Every new public API must have at least one test.
- Tests use XCTest with `async throws` methods.
- Container tests require Docker — they are integration tests.
- Always clean up containers in `tearDown` or with `defer`.

## Additional Best Practices

- Prefer `guard` over force unwrapping; avoid `try!` and `as!` in production paths.
- Propagate errors; only drop errors inside `Task {}` when explicitly acceptable.
- Keep async code cancellation-aware; avoid detached tasks unless isolation is required.
- Use `@Sendable` closure s for concurrent work and mark shared reference types `@unchecked Sendable` only with rationale.
- For parallel setup, use `withThrowingTaskGroup` instead of manual task management.
- Keep Docker endpoint configuration centralized via `Testcontainers.configure { ... }`; do not hardcode endpoints in tests.
- When stubbing in unit tests, inject protocol types (e.g., `DockerClient` protocol) rather than concrete implementations.
