import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var unitsService: UnitsService
    @State private var showSettings = false
    @State private var showProgress = false
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                avatarBlock
                themeCard
                quickLinks
                statsBlock
                signOutButton
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.md)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .toolbar(.hidden)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showEdit) { EditProfileView() }
        .navigationDestination(isPresented: $showProgress) { ProgressDashboardView() }
    }

    private var avatarBlock: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(VitalaColor.primaryGradient).frame(width: 88, height: 88)
                Text(initials).font(VitalaFont.title(28)).foregroundStyle(.white)
            }
            Text(auth.profile?.displayName ?? "Friend").font(VitalaFont.title(22))
            Text(auth.profile?.email ?? "").font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            Button("Edit profile") { showEdit = true }
                .font(VitalaFont.caption(13))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(VitalaColor.primary.opacity(0.12))
                .foregroundStyle(VitalaColor.primary)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitalaSpacing.md)
    }

    // MARK: Theme card

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            HStack {
                Text("Appearance")
                    .font(VitalaFont.headline(18))
                Spacer()
                Text(themeService.theme.label)
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            HStack(spacing: 8) {
                ForEach(AppTheme.allCases) { t in
                    ThemeChip(theme: t,
                              isSelected: themeService.theme == t) {
                        withAnimation(.smooth(duration: 0.25)) {
                            themeService.theme = t
                        }
                    }
                }
            }
        }
        .padding(VitalaSpacing.md)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: Quick links

    private var quickLinks: some View {
        VStack(spacing: 10) {
            RowItem(icon: "chart.bar.fill", iconTint: VitalaColor.primary, title: "Progress", subtitle: "Steps, calories, streaks")
                .onTapGesture { showProgress = true }
            RowItem(icon: "bell.badge.fill", iconTint: VitalaColor.coral, title: "Reminders", subtitle: "Hydration, movement, wind-down")
                .onTapGesture { showSettings = true }
            RowItem(icon: "ruler.fill", iconTint: Color(red: 0.36, green: 0.66, blue: 0.51),
                    title: "Units", subtitle: unitsService.system.shortLabel)
                .onTapGesture { showSettings = true }
            RowItem(icon: "heart.text.square.fill", iconTint: VitalaColor.sage, title: "Apple Health", subtitle: "Connected data sources")
                .onTapGesture { showSettings = true }
            RowItem(icon: "lock.shield.fill", iconTint: Color(red: 0.45, green: 0.46, blue: 0.78), title: "Privacy", subtitle: "Your data stays yours")
                .onTapGesture { showSettings = true }
        }
    }

    private var statsBlock: some View {
        HStack(spacing: 12) {
            statBox("12", "workouts")
            statBox("48", "mindful min")
            statBox("3", "day streak")
        }
    }

    private func statBox(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(VitalaFont.title(22)).foregroundStyle(VitalaColor.primary)
            Text(label).font(VitalaFont.caption(12)).foregroundStyle(VitalaColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vitalaCard(padding: 14)
    }

    private var signOutButton: some View {
        SecondaryButton(title: "Sign out", icon: "rectangle.portrait.and.arrow.right") {
            auth.signOut()
            appState.resetForSignOut()
        }
    }

    private var initials: String {
        let name = auth.profile?.displayName ?? "Friend"
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "V"
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
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
                    .font(.system(size: 16, weight: .semibold))
                Text(theme.label.components(separatedBy: " ").first ?? theme.label)
                    .font(VitalaFont.caption(12))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .fill(isSelected ? VitalaColor.primary.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .stroke(isSelected ? VitalaColor.primary : VitalaColor.muted.opacity(0.25),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .foregroundStyle(isSelected ? VitalaColor.primary : VitalaColor.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
