import SwiftUI

struct VitalaTextField: View {
    let title: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil

    @FocusState private var focused: Bool
    @State private var revealed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(VitalaFont.caption())
                .foregroundStyle(VitalaColor.textSecondary)

            HStack(spacing: VitalaSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(VitalaColor.muted)
                        .frame(width: 22)
                }
                Group {
                    if isSecure && !revealed {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .focused($focused)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                .font(VitalaFont.body())
                .foregroundStyle(VitalaColor.textPrimary)

                if isSecure {
                    Button {
                        revealed.toggle()
                    } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                            .foregroundStyle(VitalaColor.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VitalaSpacing.md)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .fill(VitalaColor.surface)
                    .shadow(color: .black.opacity(focused ? 0.08 : 0.04),
                            radius: focused ? 12 : 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .stroke(LinearGradient(
                        colors: focused
                            ? [VitalaColor.primary, VitalaColor.primary.opacity(0.6)]
                            : [.white.opacity(0.35), .white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: focused ? 1.4 : 0.7)
            )
        }
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @State var pwd = ""
    return VStack(spacing: 16) {
        VitalaTextField(title: "Email", text: $email, icon: "envelope", keyboard: .emailAddress, contentType: .emailAddress)
        VitalaTextField(title: "Password", text: $pwd, icon: "lock", isSecure: true, contentType: .password)
    }
    .padding()
    .background(VitalaColor.background)
}
