import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var notifications: NotificationService
    @EnvironmentObject var health: HealthKitService
    @EnvironmentObject var unitsService: UnitsService
    @EnvironmentObject var themeService: ThemeService
    @AppStorage("vitala.reminders") private var remindersOn: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    NavigationLink("Edit profile") { EditProfileView() }
                    NavigationLink("Goals & focus") { GoalsSettingsView() }
                    NavigationLink("Connected services") { ConnectedServicesView() }
                }

                Section("Preferences") {
                    Picker("Theme", selection: Binding(
                        get: { themeService.theme },
                        set: { themeService.theme = $0 }
                    )) {
                        ForEach(AppTheme.allCases) { t in
                            Label(t.label, systemImage: t.icon).tag(t)
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
                    Toggle("Daily reminders", isOn: $remindersOn)
                        .onChange(of: remindersOn) { _, newValue in
                            if newValue {
                                Task { _ = await notifications.request() }
                            }
                        }
                }

                Section("Privacy") {
                    NavigationLink("Privacy policy") { LegalView(title: "Privacy Policy", bodyText: privacyText) }
                    NavigationLink("Terms of service") { LegalView(title: "Terms of Service", bodyText: termsText) }
                    Button("Export my data") {}
                    Button("Delete account", role: .destructive) {}
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (1)").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct GoalsSettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var units: UnitsService
    @State private var draft: WellnessGoals = .init()

    var body: some View {
        Form {
            Section("Daily targets") {
                Stepper("Steps: \(draft.dailySteps.formatted())",
                        value: $draft.dailySteps, in: 2_000...30_000, step: 500)
                Stepper("Water: \(units.formatVolume(ml: Double(draft.dailyWaterMl)))",
                        value: $draft.dailyWaterMl, in: 1_000...4_500, step: 100)
                Stepper("Calories: \(draft.dailyCalories) kcal",
                        value: $draft.dailyCalories, in: 1_200...3_500, step: 50)
            }
            Section("Sleep") {
                HStack {
                    Text("Target hours")
                    Spacer()
                    Text(String(format: "%.1f", draft.sleepHours))
                }
                Slider(value: $draft.sleepHours, in: 5...10, step: 0.5)
            }
            Section("Focus") {
                Picker("Primary focus", selection: $draft.primaryFocus) {
                    ForEach(WellnessGoals.Focus.allCases) { f in
                        Label(f.label, systemImage: f.icon).tag(f)
                    }
                }
            }
            Section {
                Button("Save changes") {
                    Task {
                        if var profile = auth.profile {
                            profile.goals = draft
                            try? await auth.saveProfile(profile)
                        }
                    }
                }
            }
        }
        .navigationTitle("Goals")
        .onAppear {
            if let g = auth.profile?.goals { draft = g }
        }
    }
}

struct ConnectedServicesView: View {
    @EnvironmentObject var health: HealthKitService

    var body: some View {
        Form {
            Section("Apple Health") {
                HStack {
                    Image(systemName: "heart.text.square.fill").foregroundStyle(VitalaColor.coral)
                    Text("HealthKit")
                    Spacer()
                    Text(health.isAuthorized ? "Connected" : "Not connected")
                        .foregroundStyle(health.isAuthorized ? .green : .secondary)
                }
                if !health.isAuthorized {
                    Button("Connect now") {
                        Task { await health.requestAuthorization() }
                    }
                }
            }
        }
        .navigationTitle("Connections")
    }
}

struct LegalView: View {
    let title: String
    let bodyText: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(VitalaFont.title(24))
                Text(bodyText).font(VitalaFont.body(15)).foregroundStyle(VitalaColor.textSecondary)
            }
            .padding(VitalaSpacing.lg)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private let privacyText = """
Vitala respects your privacy. Health data lives on your device and in your private Firestore document. We never sell or share your data with third parties.

Health data we store:
• Profile info you enter (name, DOB, weight, height)
• Logs you create (water, meals, sleep, mindfulness, workouts)
• Aggregated daily summaries

Health data we read from Apple Health (only with your permission):
• Steps, active energy, exercise minutes
• Heart rate, resting heart rate
• Sleep analysis
• Walking + running distance

You can delete your account from Settings at any time. Doing so erases all data we store.
"""

private let termsText = """
Welcome to Vitala. By using Vitala you agree to use it as a wellness companion, not as medical advice. Always consult a qualified healthcare professional for medical concerns.

You're responsible for keeping your password safe. We're responsible for keeping your data secure and the app honest.

Be kind to yourself. Take what helps; leave what doesn't.
"""
