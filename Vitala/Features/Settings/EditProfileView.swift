import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var units: UnitsService
    @Environment(\.dismiss) var dismiss

    @State private var draft = UserProfile(id: "", email: "", displayName: "")
    @State private var heightText = ""
    @State private var weightText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $draft.displayName)
                    TextField("Email", text: $draft.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disabled(true)
                }
                Section("About you") {
                    DatePicker("Birthday",
                               selection: Binding(
                                get: { draft.dateOfBirth ?? .now },
                                set: { draft.dateOfBirth = $0 }
                               ),
                               displayedComponents: .date)
                    Picker("Gender", selection: $draft.gender) {
                        ForEach(UserProfile.Gender.allCases) { g in
                            Text(g.label).tag(g)
                        }
                    }
                    TextField("Height (\(units.heightUnitLabel()))", text: $heightText).keyboardType(.decimalPad)
                    TextField("Weight (\(units.weightUnitLabel()))", text: $weightText).keyboardType(.decimalPad)
                    Picker("Activity level", selection: $draft.activityLevel) {
                        ForEach(UserProfile.ActivityLevel.allCases) { a in
                            Text(a.label).tag(a)
                        }
                    }
                }
                Section {
                    Button {
                        save()
                    } label: {
                        Text("Save changes").bold().frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let p = auth.profile {
                    draft = p
                    if let cm = p.heightCm {
                        if units.system == .metric {
                            heightText = String(format: "%.0f", cm)
                        } else {
                            let totalIn = cm / 2.54
                            heightText = String(format: "%.0f", totalIn)  // input in inches
                        }
                    }
                    if let kg = p.weightKg {
                        weightText = String(format: "%.0f", units.displayWeight(kg: kg))
                    }
                }
            }
        }
    }

    private func save() {
        if units.system == .metric {
            draft.heightCm = Double(heightText)
        } else {
            // Imperial: input is total inches
            draft.heightCm = Double(heightText).map { $0 * 2.54 }
        }
        draft.weightKg = units.parseWeightToKg(weightText)
        Task {
            try? await auth.saveProfile(draft)
            dismiss()
        }
    }
}
