import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(VitalaFont.headline(18))
                .foregroundStyle(VitalaColor.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(VitalaFont.caption(14))
                    .foregroundStyle(VitalaColor.primary)
            }
        }
    }
}

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(VitalaFont.title(28))
                    .foregroundStyle(VitalaColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textSecondary)
                }
            }
            Spacer()
            if let trailing { trailing }
        }
    }
}
