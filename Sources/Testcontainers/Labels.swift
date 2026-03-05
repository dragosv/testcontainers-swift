import Foundation

// MARK: - Testcontainers Standard Labels

/// Standard label keys used by all Testcontainers implementations to identify
/// and manage resources created by the library.
///
/// These labels follow the Testcontainers community specification and are
/// consistent across Java, .NET, Go, and Swift implementations.
///
/// ## Label Keys
/// | Key | Description |
/// |-----|-------------|
/// | ``labelBase`` | Marks a resource as created by Testcontainers |
/// | ``labelLang`` | Identifies the language of the Testcontainers library |
/// | ``labelVersion`` | The version of the Testcontainers library |
/// | ``labelSessionId`` | The unique session ID for the current process |
///
/// ## Usage
/// Labels are automatically applied to containers and networks created through
/// ``ContainerBuilder`` and ``NetworkBuilder``. To retrieve the default label
/// set programmatically, use ``TestcontainersLabels/defaultLabels``.
public enum TestcontainersLabels {
    // MARK: - Label Keys

    /// Base label key identifying a resource as created by Testcontainers.
    ///
    /// Value is always `"true"`.
    public static let labelBase = "org.testcontainers"

    /// Label key identifying the programming language of the Testcontainers library.
    public static let labelLang = labelBase + ".lang"

    /// Label key containing the version of the Testcontainers library.
    public static let labelVersion = labelBase + ".version"

    /// Label key containing the unique session ID for the current test process.
    public static let labelSessionId = labelBase + ".sessionId"

    // MARK: - Values

    /// The language identifier for this Testcontainers implementation.
    public static let lang = "swift"

    /// The version of the testcontainers-swift library.
    ///
    /// Update this value when releasing a new version.
    public static let version = "0.1.0"

    /// A process-level session ID generated once and reused for the lifetime of the process.
    ///
    /// This unique identifier groups all containers and networks created during
    /// a single test session, enabling ecosystem tooling (e.g. Testcontainers
    /// Cloud, resource reaper) to manage resources correctly.
    public static let sessionId: String = UUID().uuidString

    // MARK: - Default Labels

    /// Returns the standard set of labels that should be applied to all
    /// Testcontainers-managed resources (containers and networks).
    ///
    /// - Returns: A dictionary containing the four standard Testcontainers labels.
    public static var defaultLabels: [String: String] {
        [
            labelBase: "true",
            labelLang: lang,
            labelVersion: version,
            labelSessionId: sessionId,
        ]
    }

    /// Merges the standard Testcontainers labels into the given label dictionary.
    ///
    /// User-defined labels with the same keys are **not** overwritten; the
    /// standard labels act as defaults.
    ///
    /// - Parameter labels: The mutable label dictionary to merge into.
    public static func addDefaultLabels(to labels: inout [String: String]) {
        for (key, value) in defaultLabels where labels[key] == nil {
            labels[key] = value
        }
    }
}
