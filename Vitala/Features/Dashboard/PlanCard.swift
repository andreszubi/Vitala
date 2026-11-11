import SwiftUI

/// One of the day's figures set against its target.
struct PlanMetric: Identifiable, Equatable {
    /// The figures a plan can put on Today.
    enum Kind: String, CaseIterable {
        case food, protein, move, steps, exercise, workouts, water, sleep, mindful
    }

    let kind: Kind
    let label: String
    let icon: String
    let value: Double
    let target: Double
    /// "1,235 of 1,850 kcal"
    let text: String
    /// True for a ceiling to stay under (food energy) rather than a target
    /// to reach.
    var isLimit = false

    var id: String { kind.rawValue }
    var progress: Double { target > 0 ? min(1, max(0, value / target)) : 0 }
    var isOver: Bool { isLimit && value > target }
    var isMet: Bool { isLimit ? value > 0 && value <= target : value >= target }

    /// The four figures that matter most for a focus, most important first.
    static func kinds(for focus: WellnessGoals.Focus) -> [Kind] {
        switch focus {
        case .loseWeight: [.food, .move, .steps, .protein]
        case .buildMuscle: [.protein, .food, .workouts, .sleep]
        case .sleepBetter: [.sleep, .mindful, .exercise, .steps]
        case .manageStress: [.mindful, .sleep, .steps, .water]
        case .balanced: [.steps, .water, .sleep, .mindful]
        }
    }
}

/// Today against the plan: the figures the user's focus puts first, each
/// with its target, and for a weight goal how far there is to go.
struct PlanCard: View {
    let profile: UserProfile?
    let metrics: [PlanMetric]
    let onUpdateWeight: () -> Void

    @EnvironmentObject var units: UnitsService

    private var goals: WellnessGoals { profile?.goals ?? WellnessGoals() }
    private var plan: GoalPlan? { profile?.plan() }
    private var aimsAtAWeight: Bool { goals.primaryFocus == .loseWeight || goals.primaryFocus == .buildMuscle }

    private var explanation: String {
        guard goals.followsPlan else { return "Your own targets. Vitala can work them out for you in Goals." }
        guard let plan else {
            return "Add your height, weight and birthday in your profile and Vitala will work out targets for you."
        }
        switch goals.primaryFocus {
        case .loseWeight, .buildMuscle:
            return plan.paceText { units.formatWeight(kg: $0, decimals: 1) }
        case .sleepBetter:
            return "Steady days make for better nights: these are the habits that help most."
        case .manageStress:
            return "A little calm, enough sleep and a walk, most days."
        case .balanced:
            return "Targets worked out for your body and your day."
        }
    }

    /// "62 kg now · 4 kg to go", when there is a weight to report.
    private var weightLine: String? {
        guard let kg = profile?.weightKg else { return nil }
        var text = "\(units.formatWeight(kg: kg, decimals: 1)) now"
        if let target = goals.weightTargetKg {
            let gap = abs(kg - target)
            let reached = goals.primaryFocus == .loseWeight ? kg <= target : kg >= target
            text += reached || gap < 0.05 ? " · target reached" : " · \(units.formatWeight(kg: gap, decimals: 1)) to go"
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader(title: "Your plan", trailing: goals.primaryFocus.label)
                Text(explanation)
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(metrics) { metric in
                    PlanMetricRow(metric: metric)
                }
            }

            if aimsAtAWeight || profile?.weightKg != nil {
                HStack(spacing: 8) {
                    if let weightLine {
                        Label(weightLine, systemImage: "scalemass.fill")
                            .font(VitalaFont.bodyMedium(14))
                            .foregroundStyle(VitalaColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Button(profile?.weightKg == nil ? "Add weight" : "Update", action: onUpdateWeight)
                        .font(VitalaFont.bodyMedium(14))
                        .foregroundStyle(VitalaColor.primary)
                        .buttonStyle(TapTargetButtonStyle())
                        .accessibilityLabel(profile?.weightKg == nil ? "Add your weight" : "Update your weight")
                        .accessibilityIdentifier("plan.updateWeight")
                }
            }
        }
        .vitalaCard()
    }
}

private struct PlanMetricRow: View {
    let metric: PlanMetric

    private var tint: Color { metric.isOver ? VitalaColor.coral : VitalaColor.primary }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: metric.icon)
                    .font(.footnote)
                    .foregroundStyle(VitalaColor.primary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Text(metric.label)
                    .font(VitalaFont.body(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                Spacer(minLength: 8)
                Text(metric.text)
                    .font(VitalaFont.bodyMedium(14))
                    .foregroundStyle(VitalaColor.textPrimary)
                    .multilineTextAlignment(.trailing)
                if metric.isMet {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(VitalaColor.success)
                        .accessibilityHidden(true)
                }
            }
            GeometryReader { geo in
                Capsule()
                    .fill(VitalaColor.primary.opacity(0.14))
                    .overlay(alignment: .leading) {
                        Capsule().fill(tint).frame(width: geo.size.width * metric.progress)
                    }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.label)
        .accessibilityValue(metric.text + (metric.isOver ? ", over your target" : metric.isMet ? ", target met" : ""))
    }
}

/// Record today's weight. The profile takes the new weight, so targets that
/// follow the plan update with it. Present inside a `NavigationStack`.
struct WeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var units: UnitsService
    @ObservedObject private var store = DataStore.shared

    @State private var weight = ""
    @State private var date = Date.now

    private var kg: Double? {
        units.parseWeightToKg(weight).flatMap { UserProfile.weightRangeKg.contains($0) ? $0 : nil }
    }

    private var recent: [WeightEntry] {
        Array(store.weights.sorted { $0.date > $1.date }.prefix(6))
    }

    var body: some View {
        Form {
            Section {
                FormTextField(label: "Weight", text: $weight, prompt: "0", unit: units.weightUnitLabel(),
                              keyboard: .decimalPad)
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: [.date])
            } footer: {
                Text(profileStore.profile?.goals.followsPlan == true
                     ? "Your targets are worked out from your weight, so they update when you save."
                     : "Saved to your profile and your weight history.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            if !recent.isEmpty {
                Section("Recent") {
                    ForEach(recent) { entry in
                        LabeledContent(entry.date.formatted(date: .abbreviated, time: .omitted),
                                       value: units.formatWeight(kg: entry.kg, decimals: 1))
                    }
                    .onDelete { offsets in
                        for index in offsets { store.deleteWeight(recent[index]) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .keyboardDoneButton()
        .navigationTitle("Weight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(kg == nil)
            }
        }
        .onAppear {
            if weight.isEmpty, let current = profileStore.profile?.weightKg {
                weight = units.displayWeight(kg: current).formatted(.number.precision(.fractionLength(0...1)))
            }
        }
    }

    private func save() {
        guard let kg else { return }
        store.logWeight(WeightEntry(date: date, kg: kg))
        // The profile holds the latest weight: only a weight for today, or
        // newer than anything recorded, changes it.
        let isLatest = !store.weights.contains { $0.date > date }
        if isLatest, var profile = profileStore.profile {
            profile.weightKg = kg
            Task { try? await profileStore.saveProfile(profile) }
        }
        Haptics.success()
        dismiss()
    }
}
