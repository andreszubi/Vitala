import SwiftUI

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(VitalaFont.headline(18))
                .foregroundStyle(VitalaColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: VitalaSpacing.xs)
            if let trailing {
                Text(trailing)
                    .font(VitalaFont.caption())
                    .foregroundStyle(VitalaColor.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.primary)
                    .buttonStyle(TapTargetButtonStyle())
            }
        }
    }
}

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil
    /// Every tab shows the profile avatar so Profile & Settings is one tap away.
    var showsProfile: Bool = true

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            // At accessibility text sizes the actions drop below the title so
            // nothing gets squeezed.
            VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
                HStack(alignment: .top) {
                    titleBlock
                    Spacer(minLength: VitalaSpacing.sm)
                    if showsProfile { ProfileButton() }
                }
                if let trailing { trailing }
            }
        } else {
            HStack(alignment: .top, spacing: VitalaSpacing.sm) {
                titleBlock
                Spacer(minLength: VitalaSpacing.sm)
                if let trailing { trailing }
                if showsProfile { ProfileButton() }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(VitalaFont.title(28))
                .foregroundStyle(VitalaColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(VitalaFont.body(15))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
    }
}
