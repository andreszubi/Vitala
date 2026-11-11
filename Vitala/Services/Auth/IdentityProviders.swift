import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Random values and hashes for sign-in requests.
enum AuthCrypto {
    /// A random string from the characters allowed in a URL, for a nonce,
    /// a state value or a PKCE verifier.
    static func randomString(length: Int = 43) -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in characters.randomElement(using: &generator)! })
    }

    /// SHA-256 as lowercase hex: what Apple wants for a nonce.
    static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// SHA-256 as URL-safe base64 with no padding: a PKCE code challenge.
    static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// What Apple hands back from a sign-in.
struct AppleCredential: Equatable {
    var identityToken: String
    /// Needed once more to revoke access when the account is deleted.
    var authorizationCode: String?
    /// The value whose hash went into the request.
    var rawNonce: String
    /// Given only the first time someone signs in to this app.
    var displayName: String?

    /// Reads what the system returned. Nil if it isn't an Apple ID
    /// credential or carries no token.
    init?(_ authorization: ASAuthorization, rawNonce: String) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else { return nil }
        identityToken = token
        authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        self.rawNonce = rawNonce
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        displayName = name.isEmpty ? nil : name
    }

    init(identityToken: String, authorizationCode: String? = nil, rawNonce: String, displayName: String? = nil) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.rawNonce = rawNonce
        self.displayName = displayName
    }
}

/// Asks Apple to confirm who the user is, outside the sign-in screen's own
/// button: used before deleting an account made with Sign in with Apple.
@MainActor
final class AppleSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AppleCredential, Error>?
    private var rawNonce = ""

    func confirm() async throws -> AppleCredential {
        rawNonce = AuthCrypto.randomString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = []
        request.nonce = AuthCrypto.sha256Hex(rawNonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = AppleCredential(authorization, rawNonce: rawNonce) {
            continuation?.resume(returning: credential)
        } else {
            continuation?.resume(throwing: AuthError.unexpected("Apple didn't return a sign-in token."))
        }
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: AuthError.fromApple(error))
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        PresentationAnchor.window
    }
}

extension AuthError {
    /// The user closing Apple's sheet isn't an error to report.
    static func fromApple(_ error: Error) -> AuthError {
        if let appleError = error as? ASAuthorizationError {
            switch appleError.code {
            case .canceled: return .cancelled
            case .notHandled, .failed, .invalidResponse, .unknown:
                return .unexpected("Apple couldn't complete the sign-in.")
            default: return .unexpected("Apple couldn't complete the sign-in.")
            }
        }
        return .unexpected("Apple couldn't complete the sign-in.")
    }
}

/// The window sign-in sheets appear over.
@MainActor
enum PresentationAnchor {
    static var window: UIWindow {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.keyWindow ?? scene?.windows.first ?? UIWindow()
    }
}

/// Sign in with Google without Google's SDK: the standard OAuth flow for an
/// installed app, in the system's own sign-in sheet. The app never sees the
/// password; it receives an identity token to hand to the account service.
struct GoogleSignIn {
    /// The iOS OAuth client id from the Google Cloud console
    /// ("1234-abc.apps.googleusercontent.com").
    let clientID: String

    private static let authorizeURL = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

    /// Google redirects to the client id written backwards.
    var callbackScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    var redirectURI: String { callbackScheme + ":/oauth2redirect" }

    /// The page to open: asks for the user's identity and nothing else.
    func authorizationURL(state: String, codeChallenge: String) -> URL {
        var components = URLComponents(string: Self.authorizeURL)!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: codeChallenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
        ]
        return components.url!
    }

    /// The authorization code in the address Google redirected to. Throws
    /// if the reply isn't for the request that was made.
    func code(from callback: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        if value("error") == "access_denied" { throw AuthError.cancelled }
        guard value("state") == expectedState, let code = value("code"), !code.isEmpty else {
            throw AuthError.unexpected("Google's reply didn't match the request.")
        }
        return code
    }

    /// The request that swaps the code for an identity token.
    func tokenRequest(code: String, verifier: String) -> URLRequest {
        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FirebaseAuthBackend.form([
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])
        return request
    }

    /// Shows Google's sign-in page and returns the identity token.
    @MainActor
    func signIn(session urlSession: URLSession = .shared) async throws -> String {
        let state = AuthCrypto.randomString(length: 24)
        let verifier = AuthCrypto.randomString(length: 64)
        let url = authorizationURL(state: state, codeChallenge: AuthCrypto.codeChallenge(for: verifier))
        let presenter = WebPresenter()
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let web = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.cancelled)
                } else {
                    continuation.resume(throwing: AuthError.unexpected("Google couldn't complete the sign-in."))
                }
            }
            web.presentationContextProvider = presenter
            if !web.start() {
                continuation.resume(throwing: AuthError.unexpected("Couldn't open Google's sign-in page."))
            }
        }
        let code = try code(from: callback, expectedState: state)
        let data: Data
        do {
            (data, _) = try await urlSession.data(for: tokenRequest(code: code, verifier: verifier))
        } catch {
            throw AuthError.network
        }
        guard let reply = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let token = reply["id_token"] as? String else {
            throw AuthError.unexpected("Google didn't return a sign-in token.")
        }
        return token
    }

    private final class WebPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            MainActor.assumeIsolated { PresentationAnchor.window }
        }
    }
}
