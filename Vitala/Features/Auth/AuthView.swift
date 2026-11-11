import AuthenticationServices
import SwiftUI

/// The first screen: Vitala needs an account, made with Apple, Google or
/// an email address.
struct AuthView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.colorScheme) private var colorScheme

    @State private var working = false
    @State private var failure: String?
    @State private var showingEmail = false
    @State private var legal: Legal?

    private enum Legal: String, Identifiable {
        case terms, privacy
        var id: String { rawValue }
    }
    /// The value whose hash goes to Apple with the request, kept to send on
    /// with the token it returns.
    @State private var appleNonce = AuthCrypto.randomString()

    private var canSignIn: Bool { auth.mode != .unavailable }

    var body: some View {
        // No navigation stack here: the email form and the legal pages open
        // as sheets, so nothing of this screen outlives it once someone has
        // signed in.
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: VitalaSpacing.lg) {
                    VStack(spacing: VitalaSpacing.sm) {
                        BrandMark(size: 84)
                            .padding(.top, VitalaSpacing.xl)
                            .accessibilityHidden(true)
                        Text("Welcome to Vitala")
                            .font(VitalaFont.title(30))
                            .foregroundStyle(VitalaColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text("Create your account, or sign in to pick up where you left off.")
                            .font(VitalaFont.body(16))
                            .foregroundStyle(VitalaColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, VitalaSpacing.sm)

                    VStack(spacing: 12) {
                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = AuthCrypto.sha256Hex(appleNonce)
                        } onCompletion: { result in
                            handleApple(result)
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 52)
                        .clipShape(Capsule())
                        .accessibilityIdentifier("auth.apple")

                        ProviderButton(title: "Continue with Google", systemImage: "g.circle.fill") {
                            run { try await auth.signInWithGoogle() }
                        }
                        .accessibilityIdentifier("auth.google")

                        ProviderButton(title: "Continue with email", systemImage: "envelope.fill") {
                            showingEmail = true
                        }
                        .accessibilityIdentifier("auth.email")
                    }
                    .disabled(working || !canSignIn)
                    .opacity(canSignIn ? 1 : 0.5)

                    if working {
                        ProgressView("Signing in…")
                            .font(VitalaFont.body(14))
                            .foregroundStyle(VitalaColor.textSecondary)
                    }

                    notice

                    VStack(spacing: 4) {
                        Text("By continuing you agree to Vitala's")
                        HStack(spacing: 4) {
                            Button("Terms of Use") { legal = .terms }
                            Text("and")
                            Button("Privacy Policy") { legal = .privacy }
                        }
                    }
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .tint(VitalaColor.primary)
                    .buttonStyle(TapTargetButtonStyle())
                }
                .padding(.horizontal, VitalaSpacing.lg)
                .padding(.bottom, VitalaSpacing.xl)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showingEmail) {
            NavigationStack { EmailAuthView() }
        }
        .sheet(item: $legal) { page in
            NavigationStack {
                LegalView(title: page == .terms ? "Terms of Use" : "Privacy Policy",
                          bodyText: page == .terms ? LegalText.terms : LegalText.privacy)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { legal = nil }
                        }
                    }
            }
        }
        .alert("Couldn't sign in", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    @ViewBuilder
    private var notice: some View {
        switch auth.mode {
        case .live:
            Label("Your account holds only your sign-in. Your logs stay on this iPhone, or in your own iCloud if you turn sync on.",
                  systemImage: "lock.shield")
                .font(VitalaFont.caption(13))
                .foregroundStyle(VitalaColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .development:
            Label("Development build: no account service is set up, so accounts are kept on this device and nothing is checked. Add your Firebase keys to Config/Secrets.xcconfig to use real accounts.",
                  systemImage: "hammer")
                .font(VitalaFont.caption(13))
                .foregroundStyle(VitalaColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .unavailable:
            Label("Signing in isn't available in this build of Vitala.", systemImage: "exclamationmark.triangle")
                .font(VitalaFont.bodyMedium(14))
                .foregroundStyle(VitalaColor.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        let nonce = appleNonce
        // Each request gets its own nonce.
        appleNonce = AuthCrypto.randomString()
        switch result {
        case .success(let authorization):
            guard let credential = AppleCredential(authorization, rawNonce: nonce) else {
                failure = "Apple didn't return a sign-in token. Try again."
                return
            }
            run { try await auth.signIn(apple: credential) }
        case .failure(let error):
            if let message = AuthError.fromApple(error).errorDescription { failure = message }
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        working = true
        Task {
            defer { working = false }
            do {
                try await work()
                Haptics.success()
            } catch let error as AuthError {
                // Closing the sheet isn't a failure.
                if let message = error.errorDescription { failure = message }
            } catch {
                failure = "Something went wrong. Try again."
            }
        }
    }
}

/// A full-width sign-in choice in Vitala's own style.
private struct ProviderButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(title)
                    .font(VitalaFont.bodyMedium(17))
            }
            .foregroundStyle(VitalaColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().fill(VitalaColor.surface))
            .overlay(Capsule().stroke(VitalaColor.hairline, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Create an account with an email address, or sign back in to one.
struct EmailAuthView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    private enum Purpose: String, CaseIterable, Identifiable {
        case create, signIn
        var id: String { rawValue }
        var label: String { self == .create ? "Create account" : "Sign in" }
    }

    @State private var purpose: Purpose = .create
    @State private var email = ""
    @State private var password = ""
    @State private var working = false
    @State private var failure: String?
    @State private var resetSentTo: String?

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && (purpose == .signIn ? !password.isEmpty : password.count >= AuthService.minimumPasswordLength)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                Picker("What would you like to do?", selection: $purpose) {
                    ForEach(Purpose.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("auth.purpose")

                VStack(spacing: VitalaSpacing.sm) {
                    VitalaTextField(title: "Email", text: $email, icon: "envelope",
                                    keyboard: .emailAddress, contentType: .username)
                    VitalaTextField(title: "Password", text: $password, icon: "lock", isSecure: true,
                                    keyboard: .asciiCapable,
                                    contentType: purpose == .create ? .newPassword : .password)
                    if purpose == .create {
                        Text("At least \(AuthService.minimumPasswordLength) characters.")
                            .font(VitalaFont.caption(13))
                            .foregroundStyle(VitalaColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                PrimaryButton(title: purpose.label, isLoading: working, isEnabled: canSubmit, action: submit)
                    .accessibilityIdentifier("auth.submit")

                if purpose == .signIn {
                    Button("Forgot your password?", action: resetPassword)
                        .font(VitalaFont.bodyMedium(15))
                        .foregroundStyle(VitalaColor.primary)
                        .buttonStyle(TapTargetButtonStyle())
                        .frame(maxWidth: .infinity)
                        .disabled(working)
                        .accessibilityHint("Sends a reset link to the email above")
                }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.vertical, VitalaSpacing.md)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle(purpose == .create ? "Create your account" : "Welcome back")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("That didn't work", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            if failure == AuthError.emailInUse.errorDescription {
                Button("Sign in instead") { purpose = .signIn }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
        .alert("Check your email", isPresented: Binding(get: { resetSentTo != nil }, set: { if !$0 { resetSentTo = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("If there is an account for \(resetSentTo ?? "that address"), a link to choose a new password is on its way.")
        }
    }

    private func submit() {
        working = true
        Task {
            defer { working = false }
            do {
                switch purpose {
                case .create: try await auth.signUp(email: email, password: password)
                case .signIn: try await auth.signIn(email: email, password: password)
                }
                Haptics.success()
                dismiss()
            } catch {
                failure = (error as? AuthError)?.errorDescription ?? "Something went wrong. Try again."
            }
        }
    }

    private func resetPassword() {
        working = true
        Task {
            defer { working = false }
            do {
                let address = try AuthService.validated(email: email)
                // Whether or not the address has an account, the answer is
                // the same, so nobody can use this to find out who does.
                try? await auth.sendPasswordReset(email: address)
                resetSentTo = address
            } catch {
                failure = "Enter your email address above first, then tap this again."
            }
        }
    }
}
