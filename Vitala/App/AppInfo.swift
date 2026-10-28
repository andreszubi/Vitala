import Foundation

/// App metadata shown in Settings and used for support links.
enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var versionString: String { "\(version) (\(build))" }

    /// Hosted copies of docs/privacy-policy.md and docs/support.md
    /// (GitHub Pages from the repository's /docs folder).
    static let privacyPolicyURL = URL(string: "https://andreszubi.github.io/Vitala/privacy-policy")!
    static let supportURL = URL(string: "https://andreszubi.github.io/Vitala/support")!
}
