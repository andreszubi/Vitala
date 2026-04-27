import SwiftUI

/// Typography ramp. Uses SF Rounded for a softer wellness feel,
/// falling back to system if the user prefers Dynamic Type accessibility sizes.
enum VitalaFont {
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func headline(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func bodyMedium(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func mono(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

extension View {
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
