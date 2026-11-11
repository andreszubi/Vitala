import Foundation

/// Accounts held by Firebase Authentication, reached over its REST API, so
/// the app needs no SDK. It stores only what signing in needs: an email
/// address, a password hash or a link to an Apple or Google identity, and
/// an account id. None of the user's logs go there.
struct FirebaseAuthBackend: AuthBackend {
    let apiKey: String
    var bundleID: String = Bundle.main.bundleIdentifier ?? "com.vitala.healthyliving"
    var session: URLSession = .shared

    private static let identity = "https://identitytoolkit.googleapis.com"
    private static let tokens = "https://securetoken.googleapis.com/v1/token"

    // MARK: AuthBackend

    func signUp(email: String, password: String) async throws -> AuthSession {
        let reply = try await post("v1/accounts:signUp",
                                   ["email": email, "password": password, "returnSecureToken": true])
        return try Self.session(from: reply, provider: .email, fallbackEmail: email)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let reply = try await post("v1/accounts:signInWithPassword",
                                   ["email": email, "password": password, "returnSecureToken": true])
        return try Self.session(from: reply, provider: .email, fallbackEmail: email)
    }

    func signIn(identityToken: String, provider: AuthProvider, rawNonce: String?,
                displayName: String?) async throws -> AuthSession {
        let reply = try await post("v1/accounts:signInWithIdp", [
            "postBody": Self.providerBody(identityToken: identityToken, provider: provider, rawNonce: rawNonce),
            "requestUri": "http://localhost",
            "returnSecureToken": true,
            "returnIdpCredential": true,
        ])
        // The email already belongs to an account made another way.
        if reply["needConfirmation"] as? Bool == true { throw AuthError.differentProvider }
        var session = try Self.session(from: reply, provider: provider, fallbackEmail: nil)
        // Apple gives the name only the first time, and only to the app.
        if session.account.displayName == nil { session.account.displayName = displayName }
        return session
    }

    func sendPasswordReset(email: String) async throws {
        _ = try await post("v1/accounts:sendOobCode", ["requestType": "PASSWORD_RESET", "email": email])
    }

    func refreshed(_ session: AuthSession) async throws -> AuthSession {
        var request = URLRequest(url: URL(string: "\(Self.tokens)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.httpBody = Self.form(["grant_type": "refresh_token", "refresh_token": session.refreshToken])
        let reply = try await send(request)
        guard let idToken = reply["id_token"] as? String,
              let refreshToken = reply["refresh_token"] as? String else {
            throw AuthError.unexpected("The reply was incomplete.")
        }
        var fresh = session
        fresh.idToken = idToken
        fresh.refreshToken = refreshToken
        fresh.idTokenExpires = Self.expiry(reply["expires_in"])
        return fresh
    }

    func revokeAppleAccess(authorizationCode: String, session: AuthSession) async throws {
        _ = try await post("v2/accounts:revokeToken", [
            "providerId": AuthProvider.apple.providerID,
            "tokenType": 3,          // an authorization code
            "token": authorizationCode,
            "idToken": session.idToken,
        ])
    }

    func deleteAccount(_ session: AuthSession) async throws {
        _ = try await post("v1/accounts:delete", ["idToken": session.idToken])
    }

    // MARK: Requests

    func request(_ path: String, _ body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "\(Self.identity)/\(path)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Lets the key be restricted to this app in the Google Cloud console.
        request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func post(_ path: String, _ body: [String: Any]) async throws -> [String: Any] {
        try await send(try request(path, body))
    }

    private func send(_ request: URLRequest) async throws -> [String: Any] {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw AuthError.cancelled
        } catch {
            throw AuthError.network
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Self.error(from: json)
        }
        return json
    }

    // MARK: Parsing

    /// The provider's token as the form body Firebase expects.
    static func providerBody(identityToken: String, provider: AuthProvider, rawNonce: String?) -> String {
        var fields = ["id_token": identityToken, "providerId": provider.providerID]
        if let rawNonce { fields["nonce"] = rawNonce }
        return String(decoding: form(fields), as: UTF8.self)
    }

    static func form(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields.sorted { $0.key < $1.key }.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }.joined(separator: "&")
        return Data(body.utf8)
    }

    static func session(from reply: [String: Any], provider: AuthProvider, fallbackEmail: String?) throws -> AuthSession {
        guard let id = reply["localId"] as? String,
              let idToken = reply["idToken"] as? String,
              let refreshToken = reply["refreshToken"] as? String else {
            throw AuthError.unexpected("The reply was incomplete.")
        }
        let email = (reply["email"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackEmail
        let name = (reply["displayName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return AuthSession(account: Account(id: id, email: email, displayName: name, provider: provider),
                           refreshToken: refreshToken, idToken: idToken,
                           idTokenExpires: expiry(reply["expiresIn"]))
    }

    /// A little before the token really runs out, so it is never used stale.
    static func expiry(_ value: Any?, now: Date = .now) -> Date {
        let seconds = (value as? String).flatMap(Double.init) ?? (value as? Double) ?? 3_600
        return now.addingTimeInterval(max(0, seconds - 60))
    }

    /// Firebase answers with a code such as "EMAIL_EXISTS", sometimes
    /// followed by a colon and an explanation.
    static func error(from reply: [String: Any]) -> AuthError {
        let message = ((reply["error"] as? [String: Any])?["message"] as? String) ?? ""
        let code = message.split(separator: ":").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        switch code {
        case "EMAIL_EXISTS": return .emailInUse
        case "INVALID_EMAIL", "MISSING_EMAIL": return .invalidEmail
        case "WEAK_PASSWORD", "MISSING_PASSWORD": return .weakPassword
        case "EMAIL_NOT_FOUND", "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS": return .wrongEmailOrPassword
        case "USER_DISABLED": return .accountDisabled
        case "TOO_MANY_ATTEMPTS_TRY_LATER": return .tooManyAttempts
        case "FEDERATED_USER_ID_ALREADY_LINKED", "EMAIL_EXISTS_WITH_DIFFERENT_CREDENTIAL": return .differentProvider
        case "CREDENTIAL_TOO_OLD_LOGIN_AGAIN", "TOKEN_EXPIRED", "INVALID_ID_TOKEN", "USER_NOT_FOUND":
            return .needsRecentSignIn
        case "OPERATION_NOT_ALLOWED":
            return .notConfigured("This way of signing in isn't switched on for Vitala yet.")
        default:
            if message.localizedCaseInsensitiveContains("API key") {
                return .notConfigured("Sign-in isn't set up correctly in this build.")
            }
            return .unexpected(message.isEmpty ? "Try again in a moment." : "(\(code))")
        }
    }
}
