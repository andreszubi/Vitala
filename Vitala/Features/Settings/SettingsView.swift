import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notifications: NotificationService
    @EnvironmentObject var health: HealthKitService
    @EnvironmentObject var unitsService: UnitsService
    @EnvironmentObject var themeService: ThemeService
    @Environment(\.openURL) private var openURL

    @State private var confirmingErase = false
    @AppStorage("vitala.onlineFoodSearch") private var onlineFoodSearch = true

    private var exportFile: ExportFile? {
        (try? DataExport(profile: profileStore.profile, store: .shared).jsonData()).map(ExportFile.init)
    }

    var body: some View {
        Form {
            Section("You") {
                NavigationLink("Edit profile") { EditProfileView() }
                NavigationLink("Goals") { GoalsSettingsView() }
            }

            Section("Preferences") {
                Picker("Appearance", selection: Binding(
                    get: { themeService.theme },
                    set: { themeService.theme = $0 }
                )) {
                    ForEach(AppTheme.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                Picker("Units", selection: Binding(
                    get: { unitsService.system },
                    set: { unitsService.system = $0 }
                )) {
                    ForEach(UnitSystem.allCases) { sys in
                        Text(sys.shortLabel).tag(sys)
                    }
                }
                NavigationLink {
                    RemindersView()
                } label: {
                    LabeledContent("Reminders", value: remindersSummary)
                }
                NavigationLink {
                    ConnectedServicesView()
                } label: {
                    LabeledContent("Apple Health", value: health.isAuthorized ? "Connected" : "Not connected")
                }
            }

            Section {
                Toggle("Search the USDA food database", isOn: $onlineFoodSearch)
            } header: {
                Text("Food search")
            } footer: {
                Text("When on, food search sends only the words you type to USDA FoodData Central to look up nutrition. Nothing else leaves your iPhone.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            Section {
                if let exportFile {
                    ShareLink(item: exportFile, preview: SharePreview("Vitala data export")) {
                        Label("Export my data", systemImage: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) {
                    confirmingErase = true
                } label: {
                    Label("Erase all data", systemImage: "trash")
                        .foregroundStyle(VitalaColor.danger)
                }
            } header: {
                Text("Your data")
            } footer: {
                Text("Vitala keeps everything on this iPhone. Export creates a JSON file you can save anywhere.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            Section("About") {
                NavigationLink("Privacy policy") { LegalView(title: "Privacy Policy", bodyText: LegalText.privacy) }
                NavigationLink("Terms of use") { LegalView(title: "Terms of Use", bodyText: LegalText.terms) }
                Button("Contact support") { openURL(AppInfo.supportURL) }
                LabeledContent("Version", value: AppInfo.versionString)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await notifications.refreshStatus() }
        .confirmationDialog("Erase all data?", isPresented: $confirmingErase, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive, action: eraseEverything)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your profile, goals and every log from this iPhone. Anything already saved to Apple Health stays there.")
        }
    }

    private var remindersSummary: String {
        guard notifications.isAllowed else { return "Off" }
        let on = notifications.reminders.filter(\.isOn).count
        return on == 0 ? "Off" : "\(on) on"
    }

    private func eraseEverything() {
        DataStore.shared.eraseAll()
        notifications.reset()
        profileStore.erase()
        unitsService.system = .metric
        themeService.theme = .system
        appState.resetAfterErase()
    }
}

// MARK: - Reminders

struct RemindersView: View {
    @EnvironmentObject var notifications: NotificationService
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            if notifications.authorizationStatus == .denied {
                Section {
                    Text("Notifications are turned off for Vitala. Turn them on in Settings to get reminders.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            } else if notifications.authorizationStatus == .notDetermined {
                Section {
                    Button("Allow notifications") {
                        Task { await notifications.request() }
                    }
                } footer: {
                    Text("Vitala asks once. You can change this later in Settings.")
                        .foregroundStyle(VitalaColor.textSecondary)
                }
            }

            Section {
                ForEach(notifications.reminders) { reminder in
                    ReminderRow(reminder: reminder) { updated in
                        Task { await notifications.update(updated) }
                    }
                }
            } footer: {
                Text("Reminders repeat daily at the times you choose.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            .disabled(notifications.authorizationStatus == .denied)
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notifications.refreshStatus() }
    }
}

private struct ReminderRow: View {
    let reminder: Reminder
    let onChange: (Reminder) -> Void

    private var time: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: reminder.hour, minute: reminder.minute, second: 0, of: .now) ?? .now },
            set: { newValue in
                var r = reminder
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                r.hour = comps.hour ?? r.hour
                r.minute = comps.minute ?? r.minute
                onChange(r)
            }
        )
    }

    var body: some View {
        Toggle(isOn: Binding(get: { reminder.isOn }, set: { var r = reminder; r.isOn = $0; onChange(r) })) {
            Label(reminder.label, systemImage: reminder.icon)
        }
        if reminder.isOn {
            DatePicker("\(reminder.label) time", selection: time, displayedComponents: .hourAndMinute)
        }
    }
}

// MARK: - Goals

struct GoalsSettingsView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WellnessGoals = .init()
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
                    SectionHeader(title: "Focus")
                    Picker("Primary focus", selection: $draft.primaryFocus) {
                        ForEach(WellnessGoals.Focus.allCases) { f in
                            Label(f.label, systemImage: f.icon).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(VitalaColor.primary)
                }
                .vitalaCard()

                VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
                    SectionHeader(title: "Daily targets")
                    GoalTargetsEditor(goals: $draft,
                                      suggestedCalories: profileStore.profile.map {
                                          var p = $0; p.goals = draft; return p
                                      }?.suggestedDailyCalories())
                }
                .vitalaCard()
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.vertical, VitalaSpacing.md)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(draft == profileStore.profile?.goals)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let g = profileStore.profile?.goals { draft = g }
        }
    }

    private func save() {
        guard var profile = profileStore.profile else { return }
        profile.goals = draft
        Task {
            try? await profileStore.saveProfile(profile)
            Haptics.success()
            dismiss()
        }
    }
}

// MARK: - Apple Health

struct ConnectedServicesView: View {
    @EnvironmentObject var health: HealthKitService
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(health.isAuthorized ? "Connected" : "Not connected")
                        .foregroundStyle(health.isAuthorized ? VitalaColor.success : VitalaColor.textSecondary)
                } label: {
                    Label("Apple Health", systemImage: "heart.text.square.fill")
                }
                if !health.isAvailable {
                    Text("Apple Health isn't available on this device.")
                        .foregroundStyle(VitalaColor.textSecondary)
                } else if !health.isAuthorized {
                    Button("Connect Apple Health") {
                        Task { await health.requestAuthorization() }
                    }
                } else {
                    Button("Open the Health app") {
                        if let url = URL(string: "x-apple-health://") { openURL(url) }
                    }
                }
            } footer: {
                Text("Vitala reads steps, active energy, exercise minutes, distance, heart rate, sleep and mindful minutes, and saves the water, sleep, mindful sessions and workouts you log. Change what Vitala can access in Settings › Health › Data Access & Devices › Vitala.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .task { await health.refreshAuthorizationState() }
    }
}

// MARK: - Legal

struct LegalView: View {
    let title: String
    let bodyText: String

    var body: some View {
        ScrollView {
            Text(bodyText)
                .font(VitalaFont.body(15))
                .foregroundStyle(VitalaColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(VitalaSpacing.lg)
                .textSelection(.enabled)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
