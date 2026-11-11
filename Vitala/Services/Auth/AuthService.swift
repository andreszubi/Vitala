import Foundation
import OSLog
import SwiftUI

/// The keys the account service needs, read from the app's Info.plist. They
/// come from Config/Secrets.xcconfig, which Git ignores.
struct AuthConfiguration: Equatable {
    /// Firebase's web API key (`API_KEY` in GoogleService-Info.plist).
    var firebaseAPIKey: String?
    /// The iOS OAuth client id (`CLIENT_ID` in GoogleService-Info.plist).
    var googleClientID: String?

    static var fromBundle: AuthConfiguration {
        func value(_ key: String) -> String? {
            guard let text = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // An unset build setting arrives empty, or as the placeholder
            // from the example file.
            return trimmed.isEmpty || trimmed.hasPrefix("paste-") ? nil : trimmed
        }
        return AuthConfiguration(firebaseAPIKey: value("FirebaseAPIKey"), googleClientID: value("GoogleClientID"))
    }
}

/// Who is signed in, and whether anyone has to be. Until an account service
/// is set up (see `AuthConfiguration`), Vitala is used without an account,
/// as it always was. Once the keys are in place the app opens on sign-in,
/// and this holds the account, keeps the session in the Keychain, and
/// signs in, out and up.
@MainActor
final class AuthService: ObservableObject {
    /// How accounts are checked in this build.
    enum Mode: Equatable {
        /// No account service is set up: nobody signs in, and the app is
        /// used without an account.
        case off
        /// Against the real account service. Signing in is required.
        case live
        /// Against a stand-in on the device, to try the sign-in screens
        /// without an account service. Signing in is required.
        case development
    }

    static let shared = AuthService.makeShared()

    nonisolated static let minimumPasswordLength = 8
    /// Whose data is on this device: an account id, and the email to name
    /// it by.
    nonisolated static let ownerKey = "vitala.dataOwner"
    nonisolated static let ownerEmailKey = "vitala.dataOwnerEmail"

    @Published private(set) var account: Account?
    let mode: Mode
    /// Nil when Google sign-in has no client id to use.
    let google: GoogleSignIn?

    private let backend: AuthBackend
    private let credentials: CredentialStore
    private let defaults: UserDefaults
    private var session: AuthSession?

    private static let log = Logger(subsystem: "com.vitala.healthyliving", category: "auth")

    init(backend: AuthBackend, credentials: CredentialStore, defaults: UserDefaults = .standard,
         mode: Mode = .live, google: GoogleSignIn? = nil) {
        self.backend = backend
        self.credentials = credentials
        self.defaults = defaults
        self.mode = mode
        self.google = google
        session = credentials.load()
        account = session?.account
    }

    var isSignedIn: Bool { account != nil }

    /// Whether the app is closed to anyone who hasn't signed in.
    var requiresSignIn: Bool { mode != .off }

    /// Whether the app can be used right now.
    var allowsEntry: Bool { isSignedIn || !requiresSignIn }

    // MARK: Signing in

    func signUp(email: String, password: String) async throws {
        let email = try Self.validated(email: email)
        guard password.count >= Self.minimumPasswordLength else { throw AuthError.weakPassword }
        adopt(try await backend.signUp(email: email, password: password))
    }

    func signIn(email: String, password: String) async throws {
        let email = try Self.validated(email: email)
        guard !password.isEmpty else { throw AuthError.wrongEmailOrPassword }
        adopt(try await backend.signIn(email: email, password: password))
    }

    func signIn(apple credential: AppleCredential) async throws {
        adopt(try await backend.signIn(identityToken: credential.identityToken, provider: .apple,
                                       rawNonce: credential.rawNonce, displayName: credential.displayName))
    }

    func signInWithGoogle() async throws {
        guard let google else {
            // A development build with no client id still lets the flow be tried.
            if mode == .development {
                adopt(try await backend.signIn(identityToken: "development-google-account", provider: .google,
                                               rawNonce: nil, displayName: nil))
                return
            }
            throw AuthError.notConfigured("Sign in with Google isn't set up in this build.")
        }
        let token = try await google.signIn()
        adopt(try await backend.signIn(identityToken: token, provider: .google, rawNonce: nil, displayName: nil))
    }

    func sendPasswordReset(email: String) async throws {
        try await backend.sendPasswordReset(email: try Self.validated(email: email))
    }

    func signOut() {
        credentials.clear()
        session = nil
        account = nil
    }

    // MARK: Deleting

    /// Deletes the account. For an account made with Sign in with Apple,
    /// `apple` is a fresh confirmation from Apple: it proves who is asking
    /// and lets Vitala hand back its access, as Apple requires.
    func deleteAccount(confirmedBy apple: AppleCredential? = nil) async throws {
        guard var current = session else { return }
        if let apple {
            current = try await backend.signIn(identityToken: apple.identityToken, provider: .apple,
                                               rawNonce: apple.rawNonce, displayName: nil)
            if let code = apple.authorizationCode {
                do {
                    try await backend.revokeAppleAccess(authorizationCode: code, session: current)
                } catch {
                    // The account is still deleted; the user can remove
                    // Vitala under Sign in with Apple in iOS Settings.
                    Self.log.error("Couldn't revoke Apple access: \(error.localizedDescription, privacy: .public)")
                }
            }
        } else if current.idTokenExpires <= .now {
            current = try await backend.refreshed(current)
        }
        try await backend.deleteAccount(current)
        defaults.removeObject(forKey: Self.ownerKey)
        defaults.removeObject(forKey: Self.ownerEmailKey)
        signOut()
    }

    // MARK: Whose data is on this device

    /// The account whose data is on this device, when it isn't the one now
    /// signed in. Their data has to be erased before a different person
    /// carries on. The value is how to name that account.
    var otherOwner: String? {
        guard let account, let owner = defaults.string(forKey: Self.ownerKey), owner != account.id else { return nil }
        return defaults.string(forKey: Self.ownerEmailKey) ?? "another account"
    }

    /// Records that the data on this device belongs to whoever is signed
    /// in. Data from before accounts existed passes to the first person to
    /// sign in.
    func claimDevice() {
        guard let account else { return }
        defaults.set(account.id, forKey: Self.ownerKey)
        defaults.set(account.email ?? "\(account.provider.label) account", forKey: Self.ownerEmailKey)
    }

    // MARK: Helpers

    private func adopt(_ new: AuthSession) {
        session = new
        credentials.save(new)
        account = new.account
        if defaults.string(forKey: Self.ownerKey) == nil { claimDevice() }
    }

    /// Trimmed and lowercased, or an error if it can't be an address.
    nonisolated static func validated(email: String) throws -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
              !parts[1].hasPrefix("."), !parts[1].hasSuffix("."),
              !trimmed.contains(" ") else { throw AuthError.invalidEmail }
        return trimmed
    }

    // MARK: The app's instance

    private static func makeShared() -> AuthService {
        #if DEBUG
        // UI tests reach the sign-in screens with this argument, against a
        // stand-in that needs no network.
        if ProcessInfo.processInfo.arguments.contains("-requireSignIn") {
            return AuthService(backend: LocalAuthBackend(), credentials: InMemoryCredentialStore(), mode: .development)
        }
        #endif
        let configuration = AuthConfiguration.fromBundle
        guard let key = configuration.firebaseAPIKey else {
            // Accounts aren't set up yet: Vitala works without one.
            return AuthService(backend: LocalAuthBackend(), credentials: InMemoryCredentialStore(), mode: .off)
        }
        return AuthService(backend: FirebaseAuthBackend(apiKey: key), credentials: KeychainCredentialStore(),
                           mode: .live, google: configuration.googleClientID.map(GoogleSignIn.init))
    }
}
