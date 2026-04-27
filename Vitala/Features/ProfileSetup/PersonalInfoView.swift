import SwiftUI

struct PersonalInfoView: View {
    @Binding var draft: UserProfile
    let onNext: () -> Void

    @EnvironmentObject var units: UnitsService

    // Display fields — refilled when system changes
    @State private var heightMetric: String = ""
    @State private var heightFeet: String = ""
    @State private var heightInches: String = ""
    @State private var weightText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tell us about you").font(VitalaFont.title(28))
                    Text("This helps Vitala personalize your daily targets.")
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textSecondary)
                }

                unitToggle

                VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
                    Text("Date of birth").font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
                    DatePicker("",
                        selection: Binding(
                            get: { draft.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -28, to: .now)! },
                            set: { draft.dateOfBirth = $0 }
                        ),
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: VitalaSpacing.xs) {
                    Text("Gender").font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(UserProfile.Gender.allCases) { g in
                            ChoiceChip(title: g.label, isSelected: draft.gender == g) {
                                draft.gender = g
                            }
                        }
                    }
                }

                heightSection
                weightSection

                Spacer().frame(height: VitalaSpacing.md)

                PrimaryButton(title: "Continue", icon: "arrow.right",
                              isEnabled: canSubmit) {
                    saveAndContinue()
                }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .onAppear { reloadFromDraft() }
        .onChange(of: units.system) { _, _ in reloadFromDraft() }
    }

    // MARK: Sections

    private var unitToggle: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.xs) {
            Text("Measurement system")
                .font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            HStack(spacing: 8) {
                ForEach(UnitSystem.allCases) { sys in
                    ChoiceChip(title: sys.shortLabel, isSelected: units.system == sys) {
                        units.system = sys
                    }
                }
            }
        }
    }

    private var heightSection: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.xs) {
            Text("Height").font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            if units.system == .metric {
                VitalaTextField(title: "cm", text: $heightMetric, icon: "ruler", keyboard: .decimalPad)
            } else {
                HStack(spacing: 12) {
                    VitalaTextField(title: "ft", text: $heightFeet, icon: "ruler", keyboard: .numberPad)
                    VitalaTextField(title: "in", text: $heightInches, keyboard: .numberPad)
                }
            }
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.xs) {
            Text("Weight").font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            VitalaTextField(title: units.weightUnitLabel(), text: $weightText,
                            icon: "scalemass", keyboard: .decimalPad)
        }
    }

    // MARK: Helpers

    private var canSubmit: Bool {
        let hasHeight: Bool = {
            if units.system == .metric { return Double(heightMetric) ?? 0 > 0 }
            return (Double(heightFeet) ?? 0) > 0
        }()
        return hasHeight && (Double(weightText) ?? 0) > 0
    }

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
        let cm: Double? = units.parseHeightToCm(metric: heightMetric, feet: heightFeet, inches: heightInches)
        let kg: Double? = units.parseWeightToKg(weightText)
        draft.heightCm = cm
        draft.weightKg = kg
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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                        .fill(isSelected ? VitalaColor.primary.opacity(0.12) : VitalaColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                        .stroke(isSelected ? VitalaColor.primary : Color.black.opacity(0.06),
                                lineWidth: isSelected ? 1.5 : 1)
                )
                .foregroundStyle(isSelected ? VitalaColor.primary : VitalaColor.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
