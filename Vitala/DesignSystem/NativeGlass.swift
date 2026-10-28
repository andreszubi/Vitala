import SwiftUI

// MARK: - Native Liquid Glass helpers
//
// On iOS 26 and later these use Apple's own Liquid Glass components (glass
// button styles, glass effect containers, scroll-edge bars). On iOS 17–25
// they fall back to Vitala's material-based look, so call sites never need
// availability checks.

extension View {
    /// System glass button style. `prominent` gives the tinted, filled variant
    /// used for primary actions.
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent).tint(tint)
            } else {
                self.buttonStyle(.glass).tint(tint)
            }
        } else {
            self.buttonStyle(PressableButtonStyle())
        }
    }

    /// Groups nearby glass controls so they blend and morph together.
    @ViewBuilder
    func glassGroup(spacing: CGFloat = 8) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }

    /// Pins actions to the bottom edge. On iOS 26+ content scrolling beneath
    /// gets the system scroll-edge glass treatment.
    @ViewBuilder
    func bottomActionBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            self.safeAreaBar(edge: .bottom) {
                content()
                    .padding(.horizontal, VitalaSpacing.lg)
                    .padding(.vertical, VitalaSpacing.sm)
            }
        } else {
            self.safeAreaInset(edge: .bottom) {
                content()
                    .padding(.horizontal, VitalaSpacing.lg)
                    .padding(.vertical, VitalaSpacing.sm)
                    .background(.ultraThinMaterial)
            }
        }
    }

    /// A "Done" button on the keyboard's accessory bar (glass on iOS 26+).
    /// Number pads have no return key, so this is the only way to dismiss them.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }

    /// Opaque cream behind sheet content on older systems; on iOS 26+ partial
    /// sheets keep the system glass background.
    @ViewBuilder
    func sheetBackground() -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            self.background(VitalaColor.background.ignoresSafeArea())
        }
    }

    /// The tab bar tucks away while scrolling down (iOS 26+).
    @ViewBuilder
    func minimizingTabBar() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}

/// A circular icon-only control: system glass on iOS 26+, a soft circle
/// before that. Always 44pt or larger and labelled for VoiceOver.
struct GlassIconButton: View {
    let systemName: String
    let label: String
    var size: CGFloat = 44
    var prominent: Bool = false
    var tint: Color? = nil
    var foreground: Color = VitalaColor.textPrimary
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .frame(width: size - 16, height: size - 16)
            }
            .buttonBorderShape(.circle)
            .glassButtonStyle(prominent: prominent, tint: tint)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(label)
        } else {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(prominent ? .white : foreground)
                    .frame(width: size, height: size)
                    .background(Circle().fill(prominent
                                              ? AnyShapeStyle(tint ?? VitalaColor.primaryFill)
                                              : AnyShapeStyle(.ultraThinMaterial)))
                    .overlay(Circle().stroke(VitalaColor.hairline, lineWidth: prominent ? 0 : 1))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(label)
        }
    }
}
