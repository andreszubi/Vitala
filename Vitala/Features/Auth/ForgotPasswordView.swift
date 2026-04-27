import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var sent = false

    var body: some View {
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reset your password")
                        .font(VitalaFont.title(28))
                        .foregroundStyle(VitalaColor.textPrimary)
                    Text("We'll email you a link to set a new password.")
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textSecondary)
                }

                VitalaTextField(title: "Email", text: $email, icon: "envelope",
                                keyboard: .emailAddress, contentType: .emailAddress)

                if sent {
                    Label("Check your inbox", systemImage: "envelope.open.fill")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VitalaColor.success.opacity(0.15))
                        .foregroundStyle(VitalaColor.success)
                        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
                }

                PrimaryButton(title: "Send reset link",
                              isEnabled: email.contains("@")) {
                    Task {
                        await auth.sendPasswordReset(email: email)
                        if auth.lastError == nil { sent = true }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.md)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
