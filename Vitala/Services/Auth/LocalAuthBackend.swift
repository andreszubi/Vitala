import CryptoKit
import Foundation

/// A stand-in for the account service that lives entirely on the device.
/// It behaves like the real one (an email can only be used once, a wrong
/// password is refused) but checks nothing with anyone. Used by tests, and
/// by development builds that have no account service set up yet.
actor LocalAuthBackend: AuthBackend {
    private struct Stored: Codable {
        var id: String
        var email: String?
        var displayName: String?
        var provider: AuthProvider
        var passwordHash: String?
    }

    private var accounts: [String: Stored] = [:]
    /// Preferences to remember accounts in between launches; nil in tests.
    private let defaults: UserDefaults?
    private static let storageKey = "vitala.debug.localAccounts"

    /// Deleted accounts' ids, so tests can see a deletion happened.
    private(set) var deleted: [String] = []
    private(set) var revokedAppleCodes: [String] = []
    private(set) var passwordResets: [String] = []
    /// When set, deleting asks for a recent sign-in first, as the real
    /// service does for sessions more than a few minutes old.
    var deletionNeedsRecentSignIn = false

    init(remembering defaults: UserDefaults? = nil) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([String: Stored].self, from: data) {
            accounts = saved
        }
    }

    func setDeletionNeedsRecentSignIn(_ needed: Bool) {
        deletionNeedsRecentSignIn = needed
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
        let key = Self.key(email)
        guard accounts[key] == nil else { throw AuthError.emailInUse }
        let stored = Stored(id: "local-" + UUID().uuidString, email: email, displayName: nil,
                            provider: .email, passwordHash: Self.hash(password))
        accounts[key] = stored
        persist()
        return Self.session(for: stored)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        guard let stored = accounts[Self.key(email)], stored.provider == .email,
              stored.passwordHash == Self.hash(password) else {
            throw AuthError.wrongEmailOrPassword
        }
        return Self.session(for: stored)
    }

    func signIn(identityToken: String, provider: AuthProvider, rawNonce: String?,
                displayName: String?) async throws -> AuthSession {
        // The same token always means the same person.
        let key = provider.rawValue + ":" + Self.hash(identityToken)
        if let stored = accounts[key] { return Self.session(for: stored) }
        let stored = Stored(id: "local-" + UUID().uuidString, email: nil, displayName: displayName,
                            provider: provider, passwordHash: nil)
        accounts[key] = stored
        persist()
        return Self.session(for: stored)
    }

    func sendPasswordReset(email: String) async throws {
        passwordResets.append(email)
    }

    func refreshed(_ session: AuthSession) async throws -> AuthSession {
        guard accounts.values.contains(where: { $0.id == session.account.id }) else {
            throw AuthError.needsRecentSignIn
        }
        var fresh = session
        fresh.idTokenExpires = .now.addingTimeInterval(3_600)
        return fresh
    }

    func revokeAppleAccess(authorizationCode: String, session: AuthSession) async throws {
        revokedAppleCodes.append(authorizationCode)
    }

    func deleteAccount(_ session: AuthSession) async throws {
        if deletionNeedsRecentSignIn { throw AuthError.needsRecentSignIn }
        accounts = accounts.filter { $0.value.id != session.account.id }
        deleted.append(session.account.id)
        persist()
    }

    private func persist() {
        guard let defaults, let data = try? JSONEncoder().encode(accounts) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func key(_ email: String) -> String {
        "email:" + email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func session(for stored: Stored) -> AuthSession {
        AuthSession(account: Account(id: stored.id, email: stored.email, displayName: stored.displayName,
                                     provider: stored.provider),
                    refreshToken: "local-refresh", idToken: "local-token-" + UUID().uuidString,
                    idTokenExpires: .now.addingTimeInterval(3_600))
    }
}
