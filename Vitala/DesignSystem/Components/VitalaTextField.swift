import SwiftUI

struct VitalaTextField: View {
    let title: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    /// Placeholder shown inside the field. The visible `title` above it is
    /// also the field's VoiceOver label.
    var placeholder: String = ""

    @FocusState private var focused: Bool
    @State private var revealed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(VitalaFont.caption())
                .foregroundStyle(VitalaColor.textSecondary)
                .accessibilityHidden(true)

            HStack(spacing: VitalaSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(VitalaColor.muted)
                        .frame(width: 22)
                        .accessibilityHidden(true)
                }
                Group {
                    if isSecure && !revealed {
                        SecureField(title, text: $text, prompt: Text(placeholder))
                    } else {
                        TextField(title, text: $text, prompt: Text(placeholder))
                    }
                }
                .focused($focused)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboard == .default ? .words : .never)
                .font(VitalaFont.body())
                .foregroundStyle(VitalaColor.textPrimary)

                if isSecure {
                    Button {
                        revealed.toggle()
                    } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                            .foregroundStyle(VitalaColor.muted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(revealed ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, VitalaSpacing.md)
            .padding(.vertical, 6)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .fill(VitalaColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .stroke(focused ? VitalaColor.primary : VitalaColor.hairline,
                            lineWidth: focused ? 1.5 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
        }
    }
}

#Preview {
    @Previewable @State var name = ""
    @Previewable @State var weight = ""
    return VStack(spacing: 16) {
        VitalaTextField(title: "First name", text: $name, icon: "person", contentType: .givenName)
        VitalaTextField(title: "Weight (kg)", text: $weight, icon: "scalemass", keyboard: .decimalPad)
    }
    .padding()
    .background(VitalaColor.background)
}
