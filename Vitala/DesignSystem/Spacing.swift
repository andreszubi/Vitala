import SwiftUI

enum VitalaSpacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

enum VitalaRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28
    static let pill: CGFloat = 999
}

extension View {
    /// Soft "card" surface used across the app — Liquid Glass styled.
    func vitalaCard(padding: CGFloat = VitalaSpacing.md,
                    corner: CGFloat = VitalaRadius.lg) -> some View {
        self
            .padding(padding)
            .glassCard(in: RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}
