import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var unitsService: UnitsService
    @EnvironmentObject var health: HealthKitService
    @EnvironmentObject var notifications: NotificationService
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var store = DataStore.shared

    @State private var showEdit = false

    private var totalWorkouts: Int { store.workouts.count }
    private var totalMindfulMinutes: Int { store.mindfulness.reduce(0) { $0 + $1.minutes } }
    private var streak: Int { Insights.currentStreak(activeDays: Insights.activeDays(store.snapshot)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                avatarBlock
                statsBlock
                quickLinks
                themeCard
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.sm)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showEdit) {
            NavigationStack { EditProfileView() }
        }
    }

    private var avatarBlock: some View {
        VStack(spacing: 10) {
            ProfilePhotoPicker { hasPhoto in
                AvatarView(size: 96)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: hasPhoto ? "pencil" : "camera.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(VitalaColor.primaryFill))
                            .overlay(Circle().stroke(VitalaColor.background, lineWidth: 2))
                    }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(profileStore.avatar == nil ? "Add profile photo" : "Change profile photo")
            Text(profileStore.profile?.displayName ?? "")
                .font(VitalaFont.title(22))
                .foregroundStyle(VitalaColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let since = profileStore.profile?.createdAt {
                Text("With Vitala since \(since.formatted(.dateTime.month(.wide).year()))")
                    .font(VitalaFont.caption())
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            Button {
                showEdit = true
            } label: {
                Text("Edit profile")
                    .font(VitalaFont.bodyMedium(15))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(VitalaColor.primary.opacity(0.12)))
                    .foregroundStyle(VitalaColor.primary)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitalaSpacing.sm)
    }

    private var statsBlock: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            statBox("\(totalWorkouts)", totalWorkouts == 1 ? "workout" : "workouts")
            statBox("\(totalMindfulMinutes)", "mindful min")
            statBox("\(streak)", "day streak")
        }
    }

    private func statBox(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(VitalaFont.title(22)).foregroundStyle(VitalaColor.primary)
            Text(label).font(VitalaFont.caption(12)).foregroundStyle(VitalaColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vitalaCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    // MARK: Quick links

    private var quickLinks: some View {
        VStack(spacing: 10) {
            NavigationLink { ProgressDashboardView() } label: {
                RowItem(icon: "chart.bar.fill", iconTint: VitalaColor.primary,
                        title: "Progress", subtitle: "Trends across movement, food, sleep and calm")
            }
            .accessibilityIdentifier("profile.progress")
            NavigationLink { GoalsSettingsView() } label: {
                RowItem(icon: "target", iconTint: VitalaColor.coralText,
                        title: "Goals", subtitle: profileStore.profile?.goals.primaryFocus.label ?? "")
            }
            NavigationLink { ConnectedServicesView() } label: {
                RowItem(icon: "heart.text.square.fill", iconTint: VitalaColor.coralText,
                        title: "Apple Health", subtitle: health.isAuthorized ? "Connected" : "Not connected")
            }
            NavigationLink { SettingsView() } label: {
                RowItem(icon: "gearshape.fill", iconTint: VitalaColor.muted,
                        title: "Settings", subtitle: "Reminders, units, privacy and your data")
            }
            .accessibilityIdentifier("profile.settings")
        }
        .buttonStyle(.plain)
    }

    // MARK: Theme card

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "Appearance", trailing: themeService.theme.label)
            HStack(spacing: 8) {
                ForEach(AppTheme.allCases) { t in
                    ThemeChip(theme: t, isSelected: themeService.theme == t) {
                        themeService.theme = t
                    }
                }
            }
        }
        .vitalaCard()
    }
}

private struct ThemeChip: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: theme.icon)
                    .font(.body.weight(.semibold))
                Text(theme.shortLabel)
                    .font(VitalaFont.caption(12))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .fill(isSelected ? VitalaColor.primary.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .stroke(isSelected ? VitalaColor.primary : VitalaColor.hairline,
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .foregroundStyle(isSelected ? VitalaColor.primary : VitalaColor.textPrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
