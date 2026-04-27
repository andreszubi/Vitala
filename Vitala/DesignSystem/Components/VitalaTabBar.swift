import SwiftUI

/// Floating Liquid Glass tab bar — translucent pill with a moving active
/// indicator. Always shows all six Vitala tabs (avoids iOS's auto-collapse
/// to "More" beyond five tabs).
struct VitalaTabBar: View {
    @Binding var selection: AppState.MainTab
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppState.MainTab.allCases) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selection == tab,
                    namespace: pillNamespace
                ) {
                    if selection != tab {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selection = tab
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
            }
        }
        .padding(6)
        .liquidGlass(in: Capsule())
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
}

private struct TabBarButton: View {
    let tab: AppState.MainTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .frame(height: 20)
                Text(tab.label)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 2)
            .foregroundStyle(isSelected ? .white : VitalaColor.textPrimary.opacity(0.55))
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(LinearGradient(
                            colors: [VitalaColor.primary, VitalaColor.sage],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .shadow(color: VitalaColor.primary.opacity(0.4),
                                radius: 8, x: 0, y: 3)
                        .matchedGeometryEffect(id: "activeTabPill", in: namespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}
