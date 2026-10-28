import SwiftUI

/// A form row with a visible label, a text field and an optional unit, so a
/// field is never identified by its placeholder alone (WCAG 3.3.2).
/// `LabeledContent` ties the visible label to the field for VoiceOver.
struct FormTextField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var unit: String? = nil
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                TextField(label, text: $text, prompt: Text(prompt))
                    .accessibilityLabel(label)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalization)
                if let unit {
                    Text(unit).foregroundStyle(VitalaColor.textSecondary)
                }
            }
        } label: {
            Text(label)
        }
    }
}
