import SwiftUI

/// The GLP-1 tracker's place on the Nutrition screen: an invitation until
/// something is logged, then the latest dose and when the next is due.
struct GLP1Card: View {
    @ObservedObject private var store = DataStore.shared
    let onOpen: () -> Void

    private var isInUse: Bool { !store.glp1Doses.isEmpty || !store.sideEffects.isEmpty }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "syringe.fill")
                    .foregroundStyle(VitalaColor.primary)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VitalaColor.primary.opacity(0.12)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("GLP-1 tracker")
                        .font(VitalaFont.bodyMedium(16))
                        .foregroundStyle(VitalaColor.textPrimary)
                    Text(subtitle)
                        .font(VitalaFont.caption(13))
                        .foregroundStyle(VitalaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(VitalaColor.muted)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(minHeight: 44)
            .surfaceCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isInUse ? "Shows your doses and side effects" : "Starts tracking doses and side effects")
        .accessibilityIdentifier("nutrition.glp1")
    }

    private var subtitle: String {
        guard let last = GLP1Schedule.latest(store.glp1Doses) else {
            return store.sideEffects.isEmpty
                ? "Log your doses and any side effects."
                : "\(store.sideEffects.count) side-effect \(store.sideEffects.count == 1 ? "note" : "notes")"
        }
        var parts = ["\(last.medicationName) \(last.amountText)"]
        if let due = GLP1Schedule.due(after: store.glp1Doses) { parts.append(due.text) }
        return parts.joined(separator: " · ")
    }
}

/// Everything logged about a GLP-1 medicine: doses and side effects, with
/// the way to add more. Present inside a `NavigationStack`.
struct GLP1View: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = DataStore.shared
    /// The day being looked at in Nutrition, used for new entries.
    var day: Date = .now

    @State private var sheet: Sheet?

    private enum Sheet: Identifiable {
        case newDose, editDose(GLP1Dose), newEffect, editEffect(SideEffectEntry)
        var id: String {
            switch self {
            case .newDose: "new-dose"
            case .editDose(let dose): dose.id
            case .newEffect: "new-effect"
            case .editEffect(let entry): entry.id
            }
        }
    }

    private var doses: [GLP1Dose] { store.glp1Doses.sorted { $0.takenAt > $1.takenAt } }
    private var effects: [SideEffectEntry] { store.sideEffects.sorted { $0.date > $1.date } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                status
                VStack(spacing: 10) {
                    PrimaryButton(title: "Log a dose", icon: "plus") { sheet = .newDose }
                        .accessibilityIdentifier("glp1.logDose")
                    SecondaryButton(title: "Log side effects", icon: "list.clipboard") { sheet = .newEffect }
                        .accessibilityIdentifier("glp1.logEffects")
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Doses", trailing: doses.isEmpty ? nil : "\(doses.count)")
                    if doses.isEmpty {
                        EmptyStateRow(text: "No doses logged yet.", icon: "syringe")
                    }
                    ForEach(doses) { dose in
                        LogRow(icon: GLP1Medication.find(dose.medicationID)?.form == .tablet ? "pills.fill" : "syringe.fill",
                               tint: VitalaColor.primary,
                               title: "\(dose.medicationName) · \(dose.amountText)",
                               subtitle: doseSubtitle(dose),
                               noun: "dose",
                               onEdit: { sheet = .editDose(dose) },
                               onDelete: { store.deleteGLP1Dose(dose) })
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Side effects", trailing: effects.isEmpty ? nil : "\(effects.count)")
                    if effects.isEmpty {
                        EmptyStateRow(text: "Nothing noted. Log how you feel whenever something comes up.",
                                      icon: "list.clipboard")
                    }
                    ForEach(effects) { entry in
                        LogRow(icon: "waveform.path.ecg",
                               tint: entry.severity == .severe ? VitalaColor.coralText : VitalaColor.mindful,
                               title: entry.summary,
                               subtitle: effectSubtitle(entry),
                               noun: "side-effect note",
                               onEdit: { sheet = .editEffect(entry) },
                               onDelete: { store.deleteSideEffect(entry) })
                    }
                }

                Text("Vitala keeps a record of what you tell it. It doesn't suggest doses or judge side effects, and it is not medical advice: follow your prescriber's instructions. If a side effect is severe, gets worse or doesn't go away, contact your prescriber or pharmacist. In an emergency, call your local emergency number.")
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.vertical, VitalaSpacing.md)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("GLP-1 tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $sheet) { sheet in
            NavigationStack {
                switch sheet {
                case .newDose: GLP1DoseSheet(on: day)
                case .editDose(let dose): GLP1DoseSheet(editing: dose)
                case .newEffect: SideEffectSheet(on: day)
                case .editEffect(let entry): SideEffectSheet(editing: entry)
                }
            }
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let last = GLP1Schedule.latest(store.glp1Doses) {
                Text("Last dose")
                    .font(VitalaFont.caption())
                    .foregroundStyle(VitalaColor.textSecondary)
                Text("\(last.medicationName) · \(last.amountText)")
                    .font(VitalaFont.headline(19))
                    .foregroundStyle(VitalaColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(last.takenAt.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))
                    .font(VitalaFont.body(15))
                    .foregroundStyle(VitalaColor.textSecondary)
                if let due = GLP1Schedule.due(after: store.glp1Doses) {
                    Label(due.text, systemImage: "calendar")
                        .font(VitalaFont.bodyMedium(15))
                        .foregroundStyle(VitalaColor.primary)
                        .padding(.top, 2)
                    Text("\(last.schedule.label) is the usual schedule for this medicine. Yours may differ.")
                        .font(VitalaFont.caption(12))
                        .foregroundStyle(VitalaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Keep track of your GLP-1 medicine")
                    .font(VitalaFont.headline(19))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text("Log each dose with the medicine, the amount and when you took it, and note any side effects, so you have the whole picture for yourself and your prescriber.")
                    .font(VitalaFont.body(15))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vitalaCard()
        .accessibilityElement(children: .combine)
    }

    private func doseSubtitle(_ dose: GLP1Dose) -> String {
        var parts = [dose.takenAt.formatted(date: .abbreviated, time: .shortened)]
        if let site = dose.site { parts.append(site.label) }
        if let notes = dose.notes, !notes.isEmpty { parts.append(notes) }
        return parts.joined(separator: " · ")
    }

    private func effectSubtitle(_ entry: SideEffectEntry) -> String {
        var parts = [entry.date.formatted(date: .abbreviated, time: .shortened), entry.severity.label]
        if let notes = entry.notes, !notes.isEmpty { parts.append(notes) }
        return parts.joined(separator: " · ")
    }
}

/// Log or edit one dose. Present inside a `NavigationStack`.
struct GLP1DoseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = DataStore.shared

    private let existing: GLP1Dose?

    @State private var medicationID: String
    @State private var customName: String
    /// One of the medicine's strengths, or `typed` for an amount entered
    /// by hand, or `noDose` until one is chosen.
    @State private var strength: Double
    @State private var customAmount: String
    @State private var takenAt: Date
    @State private var site: GLP1Dose.Site?
    @State private var notes: String
    @State private var confirmingDelete = false
    @State private var didLoad = false
    /// The medicine was just filled in from the last dose, along with its
    /// amount; that change must not clear the amount again.
    @State private var keepsAmountOnce = false

    /// Stands for "nothing chosen yet" in the medicine picker.
    private static let unchosen = ""
    /// Stand for "nothing chosen yet" and "another amount" in the dose picker.
    private static let noDose = -1.0
    private static let typed = 0.0
    /// The largest amount that can be typed, to catch slips of the finger.
    private static let largestAmount = 1_000.0

    init(on day: Date = .now) {
        existing = nil
        _medicationID = State(initialValue: Self.unchosen)
        _customName = State(initialValue: "")
        _strength = State(initialValue: Self.noDose)
        _customAmount = State(initialValue: "")
        _takenAt = State(initialValue: Self.time(on: day))
        _site = State(initialValue: nil)
        _notes = State(initialValue: "")
    }

    init(editing dose: GLP1Dose) {
        existing = dose
        let medication = GLP1Medication.find(dose.medicationID)
        let listed = medication?.strengths.contains(dose.amount) == true
        _medicationID = State(initialValue: medication?.id ?? GLP1Medication.other.id)
        _customName = State(initialValue: medication?.id == GLP1Medication.other.id || medication == nil ? dose.medicationName : "")
        _strength = State(initialValue: listed ? dose.amount : Self.typed)
        _customAmount = State(initialValue: listed ? "" : dose.amount.formatted(.number.precision(.fractionLength(0...2))))
        _takenAt = State(initialValue: dose.takenAt)
        _site = State(initialValue: dose.site)
        _notes = State(initialValue: dose.notes ?? "")
    }

    private var medication: GLP1Medication? { GLP1Medication.find(medicationID) }
    private var isOther: Bool { medicationID == GLP1Medication.other.id }
    private var unit: String { medication?.unit ?? "mg" }

    /// True when the amount is typed: "Another amount", or a medicine with
    /// no listed strengths.
    private var typesAmount: Bool {
        strength == Self.typed || medication?.strengths.isEmpty == true
    }

    private var amount: Double? {
        if !typesAmount { return strength > 0 ? strength : nil }
        let typed = customAmount.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let value = Double(typed), value.isFinite, value > 0, value <= Self.largestAmount else { return nil }
        return value
    }

    private var name: String? {
        guard let medication else { return nil }
        if !isOther { return medication.brand }
        let typed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? nil : typed
    }

    private var canSave: Bool { name != nil && amount != nil }

    /// The site of the most recent injection other than this one.
    private var lastSite: GLP1Dose.Site? {
        store.glp1Doses.filter { $0.id != existing?.id && $0.site != nil }
            .max { $0.takenAt < $1.takenAt }?.site
    }

    var body: some View {
        Form {
            Section {
                Picker("Medicine", selection: $medicationID) {
                    if medicationID == Self.unchosen {
                        Text("Choose").tag(Self.unchosen)
                    }
                    ForEach(GLP1Medication.all) { option in
                        Text(option.name).tag(option.id)
                    }
                    Text("Other").tag(GLP1Medication.other.id)
                }
                .accessibilityIdentifier("glp1.medicine")
                if isOther {
                    FormTextField(label: "Name", text: $customName, prompt: "As on the box", capitalization: .words)
                }
            } footer: {
                if let medication, !isOther {
                    Text("\(medication.schedule.label) is the usual schedule for \(medication.brand).")
                        .foregroundStyle(VitalaColor.textSecondary)
                }
            }

            if medication != nil {
                Section {
                    if let medication, !medication.strengths.isEmpty {
                        Picker("Dose", selection: $strength) {
                            if strength == Self.noDose {
                                Text("Choose").tag(Self.noDose)
                            }
                            ForEach(medication.strengths, id: \.self) { value in
                                Text(GLP1Dose.text(value, unit: medication.unit)).tag(value)
                            }
                            Text("Another amount").tag(Self.typed)
                        }
                        .accessibilityIdentifier("glp1.dose")
                    }
                    if typesAmount {
                        FormTextField(label: "Amount", text: $customAmount, prompt: "0", unit: unit, keyboard: .decimalPad)
                    }
                } footer: {
                    Text("Log the dose you were prescribed and took. Vitala doesn't suggest doses.")
                        .foregroundStyle(VitalaColor.textSecondary)
                }

                Section {
                    DatePicker("Taken", selection: $takenAt, in: ...Date.now,
                               displayedComponents: [.date, .hourAndMinute])
                    if medication?.form == .injection {
                        Picker("Injection site", selection: $site) {
                            Text("Not noted").tag(GLP1Dose.Site?.none)
                            ForEach(GLP1Dose.Site.allCases) { option in
                                Text(option.label).tag(Optional(option))
                            }
                        }
                    }
                } footer: {
                    if medication?.form == .injection, let lastSite {
                        Text("Your last injection was logged in the \(lastSite.label.lowercased()).")
                            .foregroundStyle(VitalaColor.textSecondary)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, prompt: Text("Optional"), axis: .vertical)
                        .lineLimit(2...)
                        .accessibilityLabel("Notes")
                }
            }

            if existing != nil {
                Section {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete dose", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .keyboardDoneButton()
        .navigationTitle(existing == nil ? "Log a dose" : "Edit dose")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!canSave)
            }
        }
        .confirmationDialog("Delete this dose?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let existing { store.deleteGLP1Dose(existing) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: startFromLastDose)
        .onChange(of: medicationID) { old, new in
            // A different medicine has different strengths.
            guard didLoad, old != new else { return }
            if keepsAmountOnce {
                keepsAmountOnce = false
                return
            }
            strength = Self.noDose
            customAmount = ""
            if GLP1Medication.find(new)?.form == .tablet { site = nil }
        }
    }

    /// A new dose starts from the last one logged: most people take the
    /// same medicine, and often the same amount, each time.
    private func startFromLastDose() {
        guard !didLoad else { return }
        defer { didLoad = true }
        guard existing == nil, let last = GLP1Schedule.latest(store.glp1Doses) else { return }
        let known = GLP1Medication.find(last.medicationID)
        keepsAmountOnce = true
        medicationID = known?.id ?? GLP1Medication.other.id
        if known == nil || known?.id == GLP1Medication.other.id { customName = last.medicationName }
        if known?.strengths.contains(last.amount) == true {
            strength = last.amount
        } else {
            strength = Self.typed
            customAmount = last.amount.formatted(.number.precision(.fractionLength(0...2)))
        }
    }

    private func save() {
        guard let name, let amount else { return }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        store.saveGLP1Dose(GLP1Dose(id: existing?.id ?? UUID().uuidString, takenAt: takenAt,
                                    medicationID: medicationID, medicationName: name,
                                    amount: amount, unit: unit,
                                    site: medication?.form == .injection ? site : nil,
                                    notes: trimmed.isEmpty ? nil : trimmed))
        Haptics.success()
        dismiss()
    }

    /// Now, when logging for today; otherwise midday on the chosen day.
    static func time(on day: Date) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) || day > .now { return .now }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }
}

/// Note one or more side effects. Present inside a `NavigationStack`.
struct SideEffectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = DataStore.shared

    private let existing: SideEffectEntry?

    @State private var symptoms: Set<SideEffectEntry.Symptom>
    @State private var severity: SideEffectEntry.Severity
    @State private var date: Date
    @State private var notes: String
    @State private var confirmingDelete = false

    init(on day: Date = .now) {
        existing = nil
        _symptoms = State(initialValue: [])
        _severity = State(initialValue: .mild)
        _date = State(initialValue: GLP1DoseSheet.time(on: day))
        _notes = State(initialValue: "")
    }

    init(editing entry: SideEffectEntry) {
        existing = entry
        _symptoms = State(initialValue: Set(entry.symptoms))
        _severity = State(initialValue: entry.severity)
        _date = State(initialValue: entry.date)
        _notes = State(initialValue: entry.notes ?? "")
    }

    var body: some View {
        Form {
            Section {
                ForEach(SideEffectEntry.Symptom.allCases) { symptom in
                    let isOn = symptoms.contains(symptom)
                    Button {
                        if isOn { symptoms.remove(symptom) } else { symptoms.insert(symptom) }
                    } label: {
                        HStack {
                            Text(symptom.label)
                                .foregroundStyle(VitalaColor.textPrimary)
                            Spacer()
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isOn ? VitalaColor.primary : VitalaColor.muted)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            } header: {
                Text("What did you notice?")
            } footer: {
                Text("Choose everything that applies.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            Section("How strong was it?") {
                Picker("Severity", selection: $severity) {
                    ForEach(SideEffectEntry.Severity.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                DatePicker("When", selection: $date, in: ...Date.now,
                           displayedComponents: [.date, .hourAndMinute])
            }

            Section {
                TextField("Notes", text: $notes, prompt: Text("Optional: what helped, how long it lasted"), axis: .vertical)
                    .lineLimit(3...)
                    .accessibilityLabel("Notes")
            } header: {
                Text("Notes")
            } footer: {
                Text("If a side effect is severe, gets worse or doesn't go away, contact your prescriber or pharmacist. In an emergency, call your local emergency number.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            if existing != nil {
                Section {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete note", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .keyboardDoneButton()
        .navigationTitle(existing == nil ? "Side effects" : "Edit side effects")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(symptoms.isEmpty)
            }
        }
        .confirmationDialog("Delete this note?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let existing { store.deleteSideEffect(existing) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func save() {
        guard !symptoms.isEmpty else { return }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        store.saveSideEffect(SideEffectEntry(id: existing?.id ?? UUID().uuidString, date: date,
                                             symptoms: SideEffectEntry.Symptom.allCases.filter(symptoms.contains),
                                             severity: severity, notes: trimmed.isEmpty ? nil : trimmed))
        Haptics.success()
        dismiss()
    }
}
