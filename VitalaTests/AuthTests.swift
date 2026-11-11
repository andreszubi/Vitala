import Foundation
import Testing
@testable import Vitala

@MainActor
struct AuthServiceTests {
    private func makeService(backend: LocalAuthBackend = LocalAuthBackend(),
                             credentials: InMemoryCredentialStore = InMemoryCredentialStore())
        -> (AuthService, LocalAuthBackend, InMemoryCredentialStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "VitalaAuth-\(UUID().uuidString)")!
        return (AuthService(backend: backend, credentials: credentials, defaults: defaults), backend, credentials, defaults)
    }

    @Test func nobodyIsSignedInToStartWith() {
        let (auth, _, _, _) = makeService()
        #expect(!auth.isSignedIn && auth.account == nil)
    }

    @Test func anAccountIsCreatedWithAnEmailAndStaysSignedIn() async throws {
        let (auth, backend, credentials, defaults) = makeService()
        try await auth.signUp(email: "  Sam@Example.com ", password: "correct horse")
        #expect(auth.account?.email == "sam@example.com", "tidied before it is sent")
        #expect(auth.account?.provider == .email)
        // The session is kept, so the next launch starts signed in.
        let relaunched = AuthService(backend: backend, credentials: credentials, defaults: defaults)
        #expect(relaunched.account?.email == "sam@example.com")
    }

    @Test func signingBackInNeedsTheRightPassword() async throws {
        let (auth, backend, _, _) = makeService()
        try await auth.signUp(email: "sam@example.com", password: "correct horse")
        auth.signOut()
        #expect(!auth.isSignedIn)

        await #expect(throws: AuthError.wrongEmailOrPassword) {
            try await auth.signIn(email: "sam@example.com", password: "wrong horse")
        }
        #expect(!auth.isSignedIn)
        try await auth.signIn(email: "SAM@example.com", password: "correct horse")
        #expect(auth.isSignedIn)

        // Signing out forgets the session for good.
        auth.signOut()
        let (other, _, _, _) = makeService(backend: backend)
        #expect(!other.isSignedIn)
    }

    @Test func badInputIsCaughtBeforeAnythingIsSent() async {
        let (auth, _, _, _) = makeService()
        await #expect(throws: AuthError.invalidEmail) { try await auth.signUp(email: "sam", password: "correct horse") }
        await #expect(throws: AuthError.invalidEmail) { try await auth.signUp(email: "sam@nowhere", password: "correct horse") }
        await #expect(throws: AuthError.invalidEmail) { try await auth.signIn(email: "s am@example.com", password: "x") }
        await #expect(throws: AuthError.weakPassword) { try await auth.signUp(email: "sam@example.com", password: "short") }
        #expect(!auth.isSignedIn)
    }

    @Test func anEmailCanOnlyHaveOneAccount() async throws {
        let (auth, _, _, _) = makeService()
        try await auth.signUp(email: "sam@example.com", password: "correct horse")
        auth.signOut()
        await #expect(throws: AuthError.emailInUse) {
            try await auth.signUp(email: "sam@example.com", password: "another password")
        }
    }

    @Test func appleSignInReachesTheSameAccountEachTime() async throws {
        let (auth, _, _, _) = makeService()
        let credential = AppleCredential(identityToken: "apple-token-for-sam", authorizationCode: "code-1",
                                         rawNonce: "nonce", displayName: "Sam Rivera")
        try await auth.signIn(apple: credential)
        let first = try #require(auth.account)
        #expect(first.provider == .apple && first.displayName == "Sam Rivera")
        auth.signOut()
        try await auth.signIn(apple: credential)
        #expect(auth.account?.id == first.id)
    }

    @Test func aPasswordResetGoesToATidiedAddress() async throws {
        let (auth, backend, _, _) = makeService()
        try await auth.sendPasswordReset(email: " Sam@Example.com")
        #expect(await backend.passwordResets == ["sam@example.com"])
        await #expect(throws: AuthError.invalidEmail) { try await auth.sendPasswordReset(email: "nope") }
    }

    @Test func deletingAnAccountRemovesItAndSignsOut() async throws {
        let (auth, backend, credentials, defaults) = makeService()
        try await auth.signUp(email: "sam@example.com", password: "correct horse")
        let id = try #require(auth.account?.id)
        try await auth.deleteAccount()
        #expect(!auth.isSignedIn)
        #expect(credentials.load() == nil)
        #expect(await backend.deleted == [id])
        #expect(defaults.string(forKey: AuthService.ownerKey) == nil)
        // It really is gone.
        await #expect(throws: AuthError.wrongEmailOrPassword) {
            try await auth.signIn(email: "sam@example.com", password: "correct horse")
        }
    }

    @Test func deletingAnAppleAccountHandsBackItsAccess() async throws {
        let (auth, backend, _, _) = makeService()
        try await auth.signIn(apple: AppleCredential(identityToken: "apple-token", rawNonce: "n1"))
        let id = try #require(auth.account?.id)
        // Apple confirms it's them and gives a code to revoke access with.
        try await auth.deleteAccount(confirmedBy: AppleCredential(identityToken: "apple-token",
                                                                  authorizationCode: "fresh-code", rawNonce: "n2"))
        #expect(await backend.revokedAppleCodes == ["fresh-code"])
        #expect(await backend.deleted == [id])
        #expect(!auth.isSignedIn)
    }

    @Test func aDeletionThatNeedsAFreshSignInLeavesEverythingInPlace() async throws {
        let (auth, backend, _, _) = makeService()
        try await auth.signUp(email: "sam@example.com", password: "correct horse")
        await backend.setDeletionNeedsRecentSignIn(true)
        await #expect(throws: AuthError.needsRecentSignIn) { try await auth.deleteAccount() }
        #expect(auth.isSignedIn, "still signed in, nothing lost")
        #expect(await backend.deleted.isEmpty)
    }

    @Test func theDeviceBelongsToTheFirstAccountToSignIn() async throws {
        let (auth, _, _, _) = makeService()
        try await auth.signUp(email: "sam@example.com", password: "correct horse")
        #expect(auth.otherOwner == nil)
        auth.signOut()
        #expect(auth.otherOwner == nil, "nobody is signed in to be told")

        // Someone else signs in: the data here isn't theirs.
        try await auth.signUp(email: "alex@example.com", password: "another horse")
        #expect(auth.otherOwner == "sam@example.com")
        // Once the old data is erased the device is theirs.
        auth.claimDevice()
        #expect(auth.otherOwner == nil)

        // And Sam, coming back, is told the same about Alex.
        auth.signOut()
        try await auth.signIn(email: "sam@example.com", password: "correct horse")
        #expect(auth.otherOwner == "alex@example.com")
    }

    @Test func emailsAreChecked() throws {
        #expect(try AuthService.validated(email: " Sam.Rivera+vitala@Example.co.uk ") == "sam.rivera+vitala@example.co.uk")
        for bad in ["", "sam", "sam@", "@example.com", "sam@example", "sam@.com", "sam@example.", "a b@example.com", "a@b@c.com"] {
            #expect(throws: AuthError.invalidEmail) { try AuthService.validated(email: bad) }
        }
    }

    @Test func everyErrorHasWordsExceptCancelling() {
        let errors: [AuthError] = [.invalidEmail, .weakPassword, .emailInUse, .wrongEmailOrPassword, .accountDisabled,
                                   .tooManyAttempts, .differentProvider, .needsRecentSignIn, .network,
                                   .notConfigured("Not set up."), .unexpected("(X)")]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
        #expect(AuthError.cancelled.errorDescription == nil, "closing the sheet isn't reported")
    }

    @Test func routingStartsAtSignIn() {
        let state = AppState()
        state.hasSeenOnboarding = true
        state.hasCompletedProfile = true
        let profile = UserProfile(id: "1", displayName: "Sam")
        state.resolveRoute(profile: profile, isSignedIn: false)
        #expect(state.route == .signIn)
        state.resolveRoute(profile: profile, isSignedIn: true)
        #expect(state.route == .main)
        state.resolveRoute(profile: nil, isSignedIn: true)
        #expect(state.route == .onboarding)
        state.resetAfterErase(isSignedIn: false)
        #expect(state.route == .signIn)
        state.resetAfterErase(isSignedIn: true)
        #expect(state.route == .onboarding)
    }
}

struct FirebaseAuthBackendTests {
    private let backend = FirebaseAuthBackend(apiKey: "test-key", bundleID: "com.example.app")

    private func body(_ request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try #require(json)
    }

    @Test func requestsGoToFirebaseWithTheKeyAndBundle() throws {
        let request = try backend.request("v1/accounts:signUp", ["email": "sam@example.com", "password": "pw",
                                                                  "returnSecureToken": true])
        #expect(request.url?.absoluteString == "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=test-key")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier") == "com.example.app")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let sent = try body(request)
        #expect(sent["email"] as? String == "sam@example.com")
        #expect(sent["returnSecureToken"] as? Bool == true)
    }

    @Test func aProviderTokenIsSentAsAFormWithItsNonce() {
        let apple = FirebaseAuthBackend.providerBody(identityToken: "abc.def+/=", provider: .apple, rawNonce: "raw nonce")
        #expect(apple == "id_token=abc.def%2B%2F%3D&nonce=raw%20nonce&providerId=apple.com")
        let google = FirebaseAuthBackend.providerBody(identityToken: "tok", provider: .google, rawNonce: nil)
        #expect(google == "id_token=tok&providerId=google.com")
    }

    @Test func aReplyBecomesASession() throws {
        let reply: [String: Any] = ["localId": "uid-1", "email": "sam@example.com", "idToken": "id",
                                    "refreshToken": "refresh", "expiresIn": "3600", "displayName": ""]
        let session = try FirebaseAuthBackend.session(from: reply, provider: .email, fallbackEmail: nil)
        #expect(session.account == Account(id: "uid-1", email: "sam@example.com", displayName: nil, provider: .email))
        #expect(session.refreshToken == "refresh" && session.idToken == "id")
        // Good for an hour, less a minute's margin.
        let remaining = session.idTokenExpires.timeIntervalSinceNow
        #expect(remaining > 3_500 && remaining <= 3_540)

        // Apple may hide the email; the account still exists.
        let hidden = try FirebaseAuthBackend.session(from: ["localId": "uid-2", "idToken": "id", "refreshToken": "r"],
                                                     provider: .apple, fallbackEmail: nil)
        #expect(hidden.account.email == nil && hidden.account.provider == .apple)

        #expect(throws: AuthError.self) {
            try FirebaseAuthBackend.session(from: ["localId": "uid-3"], provider: .email, fallbackEmail: nil)
        }
    }

    @Test func firebaseErrorsBecomeOurs() {
        func error(_ message: String) -> AuthError {
            FirebaseAuthBackend.error(from: ["error": ["code": 400, "message": message]])
        }
        #expect(error("EMAIL_EXISTS") == .emailInUse)
        #expect(error("INVALID_LOGIN_CREDENTIALS") == .wrongEmailOrPassword)
        #expect(error("EMAIL_NOT_FOUND") == .wrongEmailOrPassword)
        #expect(error("INVALID_PASSWORD") == .wrongEmailOrPassword)
        #expect(error("WEAK_PASSWORD : Password should be at least 6 characters") == .weakPassword)
        #expect(error("TOO_MANY_ATTEMPTS_TRY_LATER : Access to this account has been temporarily disabled") == .tooManyAttempts)
        #expect(error("USER_DISABLED") == .accountDisabled)
        #expect(error("CREDENTIAL_TOO_OLD_LOGIN_AGAIN") == .needsRecentSignIn)
        #expect(error("INVALID_EMAIL") == .invalidEmail)
        if case .notConfigured = error("OPERATION_NOT_ALLOWED") {} else { Issue.record("expected not configured") }
        if case .notConfigured = error("API key not valid. Please pass a valid API key.") {} else { Issue.record("expected not configured") }
        if case .unexpected = error("SOMETHING_NEW") {} else { Issue.record("expected unexpected") }
        if case .unexpected = FirebaseAuthBackend.error(from: [:]) {} else { Issue.record("expected unexpected") }
    }
}

struct GoogleSignInTests {
    private let google = GoogleSignIn(clientID: "1234-abcd.apps.googleusercontent.com")

    @Test func googleRedirectsToTheClientIDBackwards() {
        #expect(google.callbackScheme == "com.googleusercontent.apps.1234-abcd")
        #expect(google.redirectURI == "com.googleusercontent.apps.1234-abcd:/oauth2redirect")
    }

    @Test func thePageAsksOnlyForIdentity() throws {
        let url = google.authorizationURL(state: "state-1", codeChallenge: "challenge-1")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        #expect(url.host == "accounts.google.com")
        #expect(value("client_id") == "1234-abcd.apps.googleusercontent.com")
        #expect(value("response_type") == "code")
        #expect(value("scope") == "openid email profile")
        #expect(value("code_challenge") == "challenge-1" && value("code_challenge_method") == "S256")
        #expect(value("state") == "state-1")
        #expect(value("redirect_uri") == google.redirectURI)
    }

    @Test func theReplyMustBelongToTheRequest() throws {
        let good = URL(string: "com.googleusercontent.apps.1234-abcd:/oauth2redirect?state=state-1&code=4%2Fabc")!
        #expect(try google.code(from: good, expectedState: "state-1") == "4/abc")
        // Someone else's reply, or none.
        #expect(throws: AuthError.self) { try google.code(from: good, expectedState: "other") }
        let empty = URL(string: "com.googleusercontent.apps.1234-abcd:/oauth2redirect?state=state-1")!
        #expect(throws: AuthError.self) { try google.code(from: empty, expectedState: "state-1") }
        let denied = URL(string: "com.googleusercontent.apps.1234-abcd:/oauth2redirect?error=access_denied&state=state-1")!
        #expect(throws: AuthError.cancelled) { try google.code(from: denied, expectedState: "state-1") }
    }

    @Test func theCodeIsSwappedWithItsVerifier() throws {
        let request = google.tokenRequest(code: "4/abc", verifier: "verifier-1")
        #expect(request.url == GoogleSignIn.tokenURL && request.httpMethod == "POST")
        let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
        #expect(body.contains("code=4%2Fabc"))
        #expect(body.contains("code_verifier=verifier-1"))
        #expect(body.contains("grant_type=authorization_code"))
        #expect(!body.contains("client_secret"), "an installed app has no secret to send")
    }

    @Test func challengesFollowTheStandard() {
        // The example from RFC 7636, appendix B.
        #expect(AuthCrypto.codeChallenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
                == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        #expect(AuthCrypto.sha256Hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let a = AuthCrypto.randomString(), b = AuthCrypto.randomString()
        #expect(a.count == 43 && a != b)
        #expect(a.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "-._~".contains($0)) })
    }
}
