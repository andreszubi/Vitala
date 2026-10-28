import SwiftUI

// MARK: - Surfaces

extension View {
    /// Floating translucent surface for overlays such as bottom action bars.
    /// Uses system Liquid Glass on iOS 26 and later, and a material before that.
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            let base: Glass = tint.map { Glass.regular.tint($0.opacity(0.22)) } ?? .regular
            self.glassEffect(interactive ? base.interactive() : base, in: shape)
        } else {
            self
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        if let tint { shape.fill(tint.opacity(0.14)) }
                    }
                }
                .overlay { shape.stroke(VitalaColor.hairline, lineWidth: 1) }
                .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 6)
        }
    }

    /// The standard content card: solid surface, hairline border that stays
    /// visible in Dark Mode, and a soft shadow.
    func glassCard<S: Shape>(in shape: S = RoundedRectangle(cornerRadius: VitalaRadius.lg, style: .continuous)) -> some View {
        self
            .background { shape.fill(VitalaColor.surface) }
            .overlay { shape.stroke(VitalaColor.hairline, lineWidth: 1) }
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    /// Card surface for list rows and compact tiles.
    func surfaceCard(corner: CGFloat = VitalaRadius.md) -> some View {
        glassCard(in: RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}
