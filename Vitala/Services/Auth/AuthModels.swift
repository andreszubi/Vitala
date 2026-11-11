import Foundation

/// How someone signed in.
enum AuthProvider: String, Codable, CaseIterable {
    case apple, google, email

    var label: String {
        switch self {
        case .apple: "Apple"
        case .google: "Google"
        case .email: "Email"
        }
    }

    /// The name the identity service knows the provider by.
    var providerID: String {
        switch self {
        case .apple: "apple.com"
        case .google: "google.com"
        case .email: "password"
        }
    }
}

/// The person signed in to Vitala.
struct Account: Codable, Equatable, Identifiable {
    var id: String
    /// Nil when Apple hides it and shares nothing in its place.
    var email: String?
    var displayName: String?
    var provider: AuthProvider
}

/// An account together with what proves it: kept in the Keychain, never
/// in files or preferences.
struct AuthSession: Codable, Equatable {
    var account: Account
    /// Exchanged for a fresh identity token when the old one runs out.
    var refreshToken: String
    /// Proves who is asking, for a short while.
    var idToken: String
    var idTokenExpires: Date
}

/// What can go wrong signing in, in words for the person it happened to.
enum AuthError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case emailInUse
    case wrongEmailOrPassword
    case accountDisabled
    case tooManyAttempts
    case differentProvider
    case needsRecentSignIn
    case network
    case cancelled
    case notConfigured(String)
    case unexpected(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            "That doesn't look like an email address."
        case .weakPassword:
            "Choose a password of at least \(AuthService.minimumPasswordLength) characters."
        case .emailInUse:
            "There is already an account with that email. Sign in instead."
        case .wrongEmailOrPassword:
            "That email and password don't match an account. Check them and try again, or reset your password."
        case .accountDisabled:
            "This account has been disabled. Contact support."
        case .tooManyAttempts:
            "Too many attempts. Wait a few minutes and try again."
        case .differentProvider:
            "There is already an account with that email, created a different way. Sign in the way you did before."
        case .needsRecentSignIn:
            "For your security, sign in again and then repeat this."
        case .network:
            "Couldn't connect. Check your connection and try again."
        case .cancelled:
            nil
        case .notConfigured(let detail):
            detail
        case .unexpected(let detail):
            "Something went wrong signing in. \(detail)"
        }
    }
}

/// The service that knows who has an account. The app talks to Firebase
/// Authentication; tests and development builds use a stand-in.
protocol AuthBackend: Sendable {
    func signUp(email: String, password: String) async throws -> AuthSession
    func signIn(email: String, password: String) async throws -> AuthSession
    /// Signs in with an identity token from Apple or Google. `rawNonce` is
    /// the value whose hash was sent to Apple with the request.
    func signIn(identityToken: String, provider: AuthProvider, rawNonce: String?,
                displayName: String?) async throws -> AuthSession
    func sendPasswordReset(email: String) async throws
    /// A session with a fresh identity token.
    func refreshed(_ session: AuthSession) async throws -> AuthSession
    /// Tells Apple to forget this app's access, as Apple requires when an
    /// account made with Sign in with Apple is deleted.
    func revokeAppleAccess(authorizationCode: String, session: AuthSession) async throws
    func deleteAccount(_ session: AuthSession) async throws
}

/// Where the session is kept between launches.
protocol CredentialStore: Sendable {
    func load() -> AuthSession?
    func save(_ session: AuthSession)
    func clear()
}
