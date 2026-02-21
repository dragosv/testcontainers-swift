# Contributing to Testcontainers Swift

First off, thank you for considering contributing to Testcontainers Swift! It's people like you that make Testcontainers such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the issue list as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* **Use a clear and descriptive title**
* **Describe the exact steps which reproduce the problem**
* **Provide specific examples to demonstrate the steps**
* **Describe the behavior you observed after following the steps**
* **Explain which behavior you expected to see instead and why**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* **Use a clear and descriptive title**
* **Provide a step-by-step description of the suggested enhancement**
* **Provide specific examples to demonstrate the steps**
* **Describe the current behavior** and **the suggested behavior**

### Pull Requests

* Follow the Swift style guidelines
* Include appropriate test cases
* Update documentation as needed
* End all files with a newline

## Development Setup

1. **Fork the repository**
   ```bash
   git clone https://github.com/yourusername/testcontainers-swift.git
   ```

2. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Install dependencies**
   ```bash
   swift package resolve
   ```

4. **Build the project**
   ```bash
   swift build
   ```

5. **Run tests**
   ```bash
   swift test
   ```

## Style Guidelines

### Swift Code Style

- Use 4 spaces for indentation (no tabs)
- Use `camelCase` for variable and function names
- Use `PascalCase` for type names
- Add documentation comments for public APIs
- Keep lines under 120 characters when possible

### Example:

```swift
/// Represents a Docker container with lifecycle management
public protocol Container: AnyObject {
    /// The unique identifier of the container
    var id: String { get }
    
    /// Starts the container
    func start() async throws
    
    /// Stops the container with optional timeout
    func stop(timeout: Int) async throws
}
```

## Adding New Modules

To add a new container module:

1. Add module types in `Sources/Testcontainers/Modules.swift`
2. Implement the container class following the pattern of existing modules
3. Provide pre-configured defaults for the service
4. Add connection string methods for easy integration
5. Add tests in `Tests/`
6. Update documentation

### Module Template

```swift
public class MyServiceContainer {
    private let builder: ContainerBuilder
    private var port: Int = 5000
    
    public init(version: String = "latest") {
        let imageName = "myservice:\(version)"
        self.builder = ContainerBuilder(imageName)
            .withName("myservice-\(UUID().uuidString)")
            .withPortBinding(port, assignRandomHostPort: true)
    }
    
    public func start() async throws -> MyServiceContainerReference {
        let container = try await builder
            .withWaitStrategy(Wait.tcp(port: port))
            .buildAsync()
        
        try await container.start()
        return MyServiceContainerReference(container: container, port: port)
    }
}
```

## Testing

- Write tests for all new features
- Run tests before submitting pull requests
- Aim for high code coverage
- Tests should be deterministic and not flaky

## Documentation

- Update README.md with new features
- Add code examples for new modules
- Document API changes
- Keep examples up-to-date

## Git Commits

- Use clear and descriptive commit messages
- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

## License

By contributing, you agree that your contributions will be licensed under its MIT License.

## Questions?

Feel free to reach out to the maintainers:
- Open an issue on GitHub
- Join our Slack workspace

Thank you for contributing!
