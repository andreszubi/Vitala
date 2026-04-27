import SwiftUI

struct SignInView: View {
    let onCreateAccount: () -> Void
    let onForgotPassword: () -> Void

    @EnvironmentObject var auth: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false

    var body: some View {
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                    HStack {
                        ZStack {
                            Circle().fill(VitalaColor.primaryGradient).frame(width: 56, height: 56)
                            Image(systemName: "leaf.fill").foregroundStyle(.white)
                        }
                        Text("Vitala")
                            .font(VitalaFont.title(26))
                            .foregroundStyle(VitalaColor.primary)
                    }
                    .padding(.top, VitalaSpacing.lg)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome back").font(VitalaFont.title(30))
                            .foregroundStyle(VitalaColor.textPrimary)
                        Text("Sign in to continue your wellness journey.")
                            .font(VitalaFont.body(15))
                            .foregroundStyle(VitalaColor.textSecondary)
                    }

                    VStack(spacing: VitalaSpacing.sm) {
                        VitalaTextField(title: "Email", text: $email, icon: "envelope",
                                        keyboard: .emailAddress, contentType: .emailAddress)
                        VitalaTextField(title: "Password", text: $password, icon: "lock",
                                        isSecure: true, contentType: .password)

                        HStack {
                            Spacer()
                            Button("Forgot password?", action: onForgotPassword)
                                .font(VitalaFont.caption(13))
                                .foregroundStyle(VitalaColor.primary)
                        }
                    }
                    .padding(.top, VitalaSpacing.sm)

                    PrimaryButton(title: "Sign in",
                                  isLoading: auth.isLoading,
                                  isEnabled: canSubmit) {
                        Task { await auth.signIn(email: email, password: password) }
                    }

                    HStack {
                        line
                        Text("or").font(VitalaFont.caption(12)).foregroundStyle(VitalaColor.textSecondary)
                        line
                    }

                    SecondaryButton(title: "Continue with Apple", icon: "applelogo") {
                        // Sign in with Apple — wire up via Firebase OAuthProvider when ready.
                    }

                    HStack(spacing: 6) {
                        Spacer()
                        Text("New to Vitala?")
                            .font(VitalaFont.body(14))
                            .foregroundStyle(VitalaColor.textSecondary)
                        Button("Create account", action: onCreateAccount)
                            .font(VitalaFont.bodyMedium(14))
                            .foregroundStyle(VitalaColor.primary)
                        Spacer()
                    }
                    .padding(.top, VitalaSpacing.sm)
                }
                .padding(.horizontal, VitalaSpacing.lg)
                .padding(.bottom, VitalaSpacing.xl)
            }
        }
        .alert("Sign in failed", isPresented: .constant(auth.lastError != nil)) {
            Button("OK") { auth.lastError = nil }
        } message: {
            Text(auth.lastError?.errorDescription ?? "")
        }
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !auth.isLoading
    }

    private var line: some View {
        Rectangle().fill(VitalaColor.muted.opacity(0.3)).frame(height: 1)
    }
}
