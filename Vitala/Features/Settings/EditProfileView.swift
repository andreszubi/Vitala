import SwiftUI

/// Edit name and body details. Present inside a `NavigationStack`.
struct EditProfileView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var units: UnitsService
    @Environment(\.dismiss) var dismiss

    @State private var draft = UserProfile(id: "", displayName: "")
    @State private var hasBirthday = false
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var heightCm = ""
    @State private var heightFeet = ""
    @State private var heightInches = ""
    @State private var weightText = ""
    @State private var didLoad = false

    private var trimmedName: String { draft.displayName.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $draft.displayName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
            }

            Section {
                Toggle("Add birthday", isOn: $hasBirthday.animation())
                if hasBirthday {
                    DatePicker("Birthday", selection: $birthday, in: ...Date.now, displayedComponents: .date)
                }
                Picker("Gender", selection: $draft.gender) {
                    ForEach(UserProfile.Gender.allCases) { g in
                        Text(g.label).tag(g)
                    }
                }
                Picker("Activity level", selection: $draft.activityLevel) {
                    ForEach(UserProfile.ActivityLevel.allCases) { a in
                        Text(a.label).tag(a)
                    }
                }
            } header: {
                Text("About you")
            } footer: {
                Text("Used only on this device to personalise your targets.")
            }

            Section("Body") {
                if units.system == .metric {
                    numberField("Height", text: $heightCm, unit: "cm")
                } else {
                    numberField("Height, feet", text: $heightFeet, unit: "ft", decimal: false)
                    numberField("Height, inches", text: $heightInches, unit: "in", decimal: false)
                }
                numberField("Weight", text: $weightText, unit: units.weightUnitLabel())
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(trimmedName.isEmpty)
            }
        }
        .keyboardDoneButton()
        .onAppear(perform: load)
    }

    private func numberField(_ label: String, text: Binding<String>, unit: String, decimal: Bool = true) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, text: text, prompt: Text("0"))
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
            Text(unit)
                .foregroundStyle(VitalaColor.textSecondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func load() {
        guard !didLoad, let p = profileStore.profile else { return }
        didLoad = true
        draft = p
        if let dob = p.dateOfBirth {
            hasBirthday = true
            birthday = dob
        }
        if let cm = p.heightCm {
            heightCm = String(format: "%.0f", cm)
            let split = units.cmToFeetInches(cm)
            heightFeet = String(split.feet)
            heightInches = String(split.inches)
        }
        if let kg = p.weightKg {
            weightText = String(format: "%.0f", units.displayWeight(kg: kg))
        }
    }

    private func save() {
        draft.displayName = trimmedName
        draft.dateOfBirth = hasBirthday ? birthday : nil
        if let cm = units.parseHeightToCm(metric: heightCm, feet: heightFeet, inches: heightInches), cm > 0 {
            draft.heightCm = cm
        }
        if let kg = units.parseWeightToKg(weightText), kg > 0 {
            draft.weightKg = kg
        }
        Task {
            try? await profileStore.saveProfile(draft)
            Haptics.success()
            dismiss()
        }
    }
}
