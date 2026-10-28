import SwiftUI

struct PersonalInfoView: View {
    @Binding var draft: UserProfile
    let onNext: () -> Void

    @EnvironmentObject var units: UnitsService
    @Environment(\.dynamicTypeSize) private var typeSize

    // Display fields — refilled when the unit system changes.
    @State private var heightMetric: String = ""
    @State private var heightFeet: String = ""
    @State private var heightInches: String = ""
    @State private var weightText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tell us about you")
                        .font(VitalaFont.title(28))
                        .foregroundStyle(VitalaColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Optional — it helps Vitala suggest daily targets. It never leaves this device.")
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textSecondary)
                }

                field("Measurement system") {
                    HStack(spacing: 8) {
                        ForEach(UnitSystem.allCases) { sys in
                            ChoiceChip(title: sys.shortLabel, isSelected: units.system == sys) {
                                units.system = sys
                            }
                        }
                    }
                }

                field("Date of birth") {
                    DatePicker("Date of birth",
                        selection: Binding(
                            get: { draft.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -30, to: .now)! },
                            set: { draft.dateOfBirth = $0 }
                        ),
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(VitalaColor.primary)
                }

                field("Gender") {
                    LazyVGrid(columns: chipColumns, spacing: 8) {
                        ForEach(UserProfile.Gender.allCases) { g in
                            ChoiceChip(title: g.label, isSelected: draft.gender == g) {
                                draft.gender = g
                            }
                        }
                    }
                }

                field("How active are you?") {
                    VStack(spacing: 8) {
                        ForEach(UserProfile.ActivityLevel.allCases) { level in
                            ChoiceChip(title: level.label, isSelected: draft.activityLevel == level) {
                                draft.activityLevel = level
                            }
                        }
                    }
                }

                heightSection
                weightSection

                PrimaryButton(title: "Continue", icon: "arrow.right", isEnabled: isValid) {
                    saveAndContinue()
                }
                .padding(.top, VitalaSpacing.sm)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.md)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .onAppear { reloadFromDraft() }
        .onChange(of: units.system) { _, _ in reloadFromDraft() }
    }

    private var chipColumns: [GridItem] {
        typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
    }

    // MARK: Sections

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.xs) {
            Text(label)
                .font(VitalaFont.caption())
                .foregroundStyle(VitalaColor.textSecondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private var heightSection: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.xs) {
            if units.system == .metric {
                VitalaTextField(title: "Height (cm)", text: $heightMetric, icon: "ruler", keyboard: .decimalPad)
            } else {
                HStack(spacing: 12) {
                    VitalaTextField(title: "Height (ft)", text: $heightFeet, icon: "ruler", keyboard: .numberPad)
                    VitalaTextField(title: "Height (in)", text: $heightInches, keyboard: .numberPad)
                }
            }
            if !heightIsValid {
                validationMessage("Enter a height between \(units.formatHeight(cm: UserProfile.heightRangeCm.lowerBound)) and \(units.formatHeight(cm: UserProfile.heightRangeCm.upperBound)).")
            }
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.xs) {
            VitalaTextField(title: "Weight (\(units.weightUnitLabel()))", text: $weightText,
                            icon: "scalemass", keyboard: .decimalPad)
            if !weightIsValid {
                validationMessage("Enter a weight between \(units.formatWeight(kg: UserProfile.weightRangeKg.lowerBound)) and \(units.formatWeight(kg: UserProfile.weightRangeKg.upperBound)).")
            }
        }
    }

    private func validationMessage(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle")
            .font(VitalaFont.caption(12))
            .foregroundStyle(VitalaColor.danger)
    }

    // MARK: Validation

    private var heightEntered: Bool {
        units.system == .metric ? !heightMetric.isEmpty : !(heightFeet.isEmpty && heightInches.isEmpty)
    }
    private var parsedHeight: Double? {
        units.parseHeightToCm(metric: heightMetric, feet: heightFeet, inches: heightInches)
    }
    private var heightIsValid: Bool {
        !heightEntered || parsedHeight.map(UserProfile.heightRangeCm.contains) == true
    }
    private var weightIsValid: Bool {
        weightText.isEmpty || units.parseWeightToKg(weightText).map(UserProfile.weightRangeKg.contains) == true
    }
    private var isValid: Bool { heightIsValid && weightIsValid }

    // MARK: Helpers

    private func reloadFromDraft() {
        if let cm = draft.heightCm {
            heightMetric = String(format: "%.0f", cm)
            let (f, i) = units.cmToFeetInches(cm)
            heightFeet = String(f); heightInches = String(i)
        }
        if let kg = draft.weightKg {
            weightText = String(format: "%.0f", units.displayWeight(kg: kg))
        }
    }

    private func saveAndContinue() {
        draft.heightCm = heightEntered ? parsedHeight : nil
        draft.weightKg = weightText.isEmpty ? nil : units.parseWeightToKg(weightText)
        if draft.dateOfBirth == nil {
            draft.dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: .now)
        }
        // Start from a personal calorie target when we can estimate one,
        // unless the user already picked their own.
        if draft.goals.dailyCalories == WellnessGoals().dailyCalories,
           let suggested = draft.suggestedDailyCalories() {
            draft.goals.dailyCalories = suggested
        }
        onNext()
    }
}

struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(VitalaFont.bodyMedium(15))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                        .fill(isSelected ? VitalaColor.primary.opacity(0.12) : VitalaColor.surface)
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
