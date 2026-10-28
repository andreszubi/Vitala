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
                    .frame(minHeight: 44)
            }
        }
    }
}

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility text sizes the action drops below the title so
        // neither gets squeezed.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: VitalaSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .top))
        layout {
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
            if !typeSize.isAccessibilitySize { Spacer(minLength: VitalaSpacing.sm) }
            if let trailing { trailing }
        }
    }
}
