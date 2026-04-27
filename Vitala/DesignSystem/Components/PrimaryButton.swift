import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VitalaSpacing.xs) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    if let icon { Image(systemName: icon) }
                    Text(title).font(VitalaFont.bodyMedium(17))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule(style: .continuous)
                    .fill(LinearGradient(
                        colors: [VitalaColor.primary, VitalaColor.sage],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .opacity(isEnabled ? 1 : 0.45)
            )
            .overlay(
                // Gloss highlight along the top edge.
                Capsule(style: .continuous)
                    .stroke(LinearGradient(
                        colors: [.white.opacity(0.55), .white.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    ), lineWidth: 0.8)
            )
            .foregroundStyle(.white)
            .shadow(color: VitalaColor.primary.opacity(0.35), radius: 14, x: 0, y: 7)
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VitalaSpacing.xs) {
                if let icon { Image(systemName: icon) }
                Text(title).font(VitalaFont.bodyMedium(17))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(VitalaColor.primary)
            .liquidGlass(in: Capsule(style: .continuous),
                         tint: VitalaColor.primary,
                         strokeOpacity: 0.55)
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(VitalaFont.bodyMedium(15))
                .foregroundStyle(VitalaColor.primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 14) {
        PrimaryButton(title: "Continue", icon: "arrow.right") {}
        SecondaryButton(title: "Sign in with Apple", icon: "applelogo") {}
        GhostButton(title: "Skip for now") {}
    }
    .padding()
    .background(VitalaColor.background)
}
