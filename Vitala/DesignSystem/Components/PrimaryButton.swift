import SwiftUI

/// Gentle press feedback shared by Vitala's custom buttons.
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    private var label: some View {
        HStack(spacing: VitalaSpacing.xs) {
            if isLoading {
                ProgressView().tint(.white)
            } else {
                if let icon { Image(systemName: icon).accessibilityHidden(true) }
                Text(title).font(VitalaFont.bodyMedium(17))
            }
        }
        .multilineTextAlignment(.center)
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                // Native Liquid Glass, tinted with the brand fill.
                Button(action: action) {
                    label
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(VitalaColor.primaryFill)
            } else {
                Button(action: action) {
                    label
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .padding(.horizontal, VitalaSpacing.md)
                        .background(
                            Capsule(style: .continuous)
                                .fill(VitalaColor.primaryGradient)
                                .opacity(isEnabled ? 1 : 0.4)
                        )
                        .foregroundStyle(.white)
                        .shadow(color: VitalaColor.primaryFill.opacity(isEnabled ? 0.3 : 0), radius: 12, x: 0, y: 6)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "In progress" : "")
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var role: ButtonRole? = nil
    let action: () -> Void

    private var tint: Color {
        role == .destructive ? VitalaColor.danger : VitalaColor.primary
    }

    private var label: some View {
        HStack(spacing: VitalaSpacing.xs) {
            if let icon { Image(systemName: icon).accessibilityHidden(true) }
            Text(title).font(VitalaFont.bodyMedium(17))
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(tint)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: role, action: action) {
                label
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        } else {
            Button(role: role, action: action) {
                label
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(.horizontal, VitalaSpacing.md)
                    .background(Capsule(style: .continuous).fill(tint.opacity(0.10)))
                    .overlay(Capsule(style: .continuous).stroke(tint.opacity(0.35), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Small capsule action used in screen headers ("Log", "Add").
struct HeaderActionButton: View {
    let title: String
    var icon: String = "plus"
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) {
                    Label(title, systemImage: icon)
                        .font(VitalaFont.bodyMedium(15))
                        .frame(minHeight: 30)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(VitalaColor.primaryFill)
            } else {
                Button(action: action) {
                    Label(title, systemImage: icon)
                        .font(VitalaFont.bodyMedium(15))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(VitalaColor.primaryGradient))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .frame(minHeight: 44)
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}

#Preview {
    VStack(spacing: 14) {
        PrimaryButton(title: "Continue", icon: "arrow.right") {}
        SecondaryButton(title: "Export my data", icon: "square.and.arrow.up") {}
        GhostButton(title: "Skip for now") {}
        HeaderActionButton(title: "Log") {}
    }
    .padding()
    .background(VitalaColor.background)
}
