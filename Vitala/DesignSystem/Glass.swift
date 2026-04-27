import SwiftUI

// MARK: - Liquid Glass

/// Concentric corner radii for Liquid Glass surfaces. Always use these so
/// nested shapes stay visually concentric.
enum GlassRadius {
    static let sm: CGFloat = 14
    static let md: CGFloat = 22
    static let lg: CGFloat = 28
    static let pill: CGFloat = 999
}

extension View {
    /// Applies the Vitala "Liquid Glass" treatment: translucent material,
    /// gradient highlight stroke, and a soft drop shadow. Use for floating
    /// surfaces — tab bars, sheet headers, modal panels.
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S,
                               tint: Color? = nil,
                               strokeOpacity: Double = 0.45) -> some View {
        self
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if let tint {
                        shape.fill(tint.opacity(0.18))
                    }
                }
            }
            .overlay {
                shape
                    .stroke(LinearGradient(
                        colors: [
                            .white.opacity(strokeOpacity),
                            .white.opacity(strokeOpacity * 0.18),
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
    }

    /// A solid-but-glassy card surface. Less transparent than `liquidGlass` —
    /// good for content cards stacked on a colored background.
    func glassCard<S: Shape>(in shape: S = RoundedRectangle(cornerRadius: GlassRadius.md, style: .continuous)) -> some View {
        self
            .background {
                shape.fill(VitalaColor.surface)
            }
            .overlay {
                shape.stroke(LinearGradient(
                    colors: [.white.opacity(0.35), .white.opacity(0.0)],
                    startPoint: .top, endPoint: .bottom
                ), lineWidth: 0.6)
            }
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 5)
    }
}
