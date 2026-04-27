import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var auth: AuthService
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var acceptedTerms = false

    var body: some View {
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Create your account")
                            .font(VitalaFont.title(28))
                            .foregroundStyle(VitalaColor.textPrimary)
                        Text("A few details and you're in.")
                            .font(VitalaFont.body(15))
                            .foregroundStyle(VitalaColor.textSecondary)
                    }
                    .padding(.top, VitalaSpacing.md)

                    VStack(spacing: VitalaSpacing.sm) {
                        VitalaTextField(title: "Your name", text: $name, icon: "person",
                                        contentType: .name)
                        VitalaTextField(title: "Email", text: $email, icon: "envelope",
                                        keyboard: .emailAddress, contentType: .emailAddress)
                        VitalaTextField(title: "Password", text: $password, icon: "lock",
                                        isSecure: true, contentType: .newPassword)

                        HStack(spacing: 8) {
                            Button {
                                acceptedTerms.toggle()
                            } label: {
                                Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(acceptedTerms ? VitalaColor.primary : VitalaColor.muted)
                                    .font(.system(size: 22))
                            }
                            .buttonStyle(.plain)
                            (Text("I agree to the ") + Text("Terms").foregroundColor(VitalaColor.primary) +
                             Text(" and ") + Text("Privacy Policy").foregroundColor(VitalaColor.primary))
                                .font(VitalaFont.caption(13))
                                .foregroundStyle(VitalaColor.textSecondary)
                            Spacer()
                        }
                        .padding(.top, 6)
                    }

                    PrimaryButton(title: "Create account",
                                  isLoading: auth.isLoading,
                                  isEnabled: canSubmit) {
                        Task { await auth.signUp(email: email, password: password, displayName: name) }
                    }
                }
                .padding(.horizontal, VitalaSpacing.lg)
                .padding(.bottom, VitalaSpacing.xl)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't create account", isPresented: .constant(auth.lastError != nil)) {
            Button("OK") { auth.lastError = nil }
        } message: {
            Text(auth.lastError?.errorDescription ?? "")
        }
    }

    private var canSubmit: Bool {
        !name.isEmpty && email.contains("@") && password.count >= 8 && acceptedTerms && !auth.isLoading
    }
}
