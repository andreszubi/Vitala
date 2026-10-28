import SwiftUI

/// Typography ramp in SF Rounded for a softer wellness feel.
///
/// Every font is built on a system text style, so it scales with the user's
/// Dynamic Type setting (including accessibility sizes). The point size a
/// caller passes picks the nearest text style at the default size — e.g.
/// `title(28)` is `.title`, `caption(12)` is `.caption`.
enum VitalaFont {
    static func display(_ size: CGFloat = 34) -> Font {
        rounded(size, weight: .bold)
    }
    static func title(_ size: CGFloat = 28) -> Font {
        rounded(size, weight: .bold)
    }
    static func headline(_ size: CGFloat = 20) -> Font {
        rounded(size, weight: .semibold)
    }
    static func body(_ size: CGFloat = 17) -> Font {
        rounded(size, weight: .regular)
    }
    static func bodyMedium(_ size: CGFloat = 17) -> Font {
        rounded(size, weight: .medium)
    }
    static func caption(_ size: CGFloat = 13) -> Font {
        rounded(size, weight: .medium)
    }
    static func mono(_ size: CGFloat = 17) -> Font {
        .system(textStyle(for: size), design: .monospaced, weight: .semibold)
    }
    private static func rounded(_ size: CGFloat, weight: Font.Weight) -> Font {
        .system(textStyle(for: size), design: .rounded, weight: weight)
    }

    /// Nearest system text style for a point size at the default content size.
    static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 34...:     .largeTitle   // 34
        case 26..<34:   .title        // 28
        case 21..<26:   .title2       // 22
        case 18..<21:   .title3       // 20
        case 16.5..<18: .body         // 17
        case 15.5..<16.5: .callout    // 16
        case 14..<15.5: .subheadline  // 15
        case 12.5..<14: .footnote     // 13
        case 11.5..<12.5: .caption    // 12
        default:        .caption2     // 11
        }
    }
}

/// Large numerals (timers, hero stats) that scale with Dynamic Type
/// relative to `.largeTitle`.
private struct NumeralFont: ViewModifier {
    @ScaledMetric private var size: CGFloat

    init(size: CGFloat) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
    }
}

extension View {
    func numeralFont(_ size: CGFloat) -> some View {
        modifier(NumeralFont(size: size))
    }

    func vitalaTitle() -> some View {
        self.font(VitalaFont.title()).foregroundStyle(VitalaColor.textPrimary)
    }
    func vitalaHeadline() -> some View {
        self.font(VitalaFont.headline()).foregroundStyle(VitalaColor.textPrimary)
    }
    func vitalaBody() -> some View {
        self.font(VitalaFont.body()).foregroundStyle(VitalaColor.textPrimary)
    }
    func vitalaCaption() -> some View {
        self.font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
    }
}
