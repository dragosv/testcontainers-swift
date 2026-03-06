/// Single source of truth for the **testcontainers-swift** library version.
///
/// All version references (labels, HTTP headers, User-Agent) read from here.
/// When cutting a new release, update ``current`` and tag the commit.
public enum PackageVersion {
    /// The current semantic version of testcontainers-swift.
    public static let current = "0.1.0"
}
