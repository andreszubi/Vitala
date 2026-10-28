import SwiftUI

/// Log or edit a meal. Present inside a `NavigationStack`.
struct AddMealView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var store = DataStore.shared

    /// If non-nil, the form is in edit mode for this meal.
    var editing: Meal? = nil
    /// Meal type to start with when logging a new meal.
    var initialType: Meal.MealType? = nil
    /// Optional default date (used when logging from a past-day Nutrition view).
    var forDate: Date? = nil

    @State private var query: String = ""
    @State private var mealType: Meal.MealType = .suggested()
    @State private var selected: [FoodItem] = []
    @State private var saving = false
    @State private var showCustomSheet = false
    @State private var didLoad = false
    @State private var showDeleteConfirm = false

    // Online search (USDA FoodData Central)
    @AppStorage("vitala.onlineFoodSearch") private var onlineSearchEnabled = true
    @State private var online: [FoodSearchResult] = []
    @State private var onlineState: OnlineState = .idle
    @State private var portionFor: FoodSearchResult?
    private let foodDatabase = FoodDatabaseClient()

    // Barcode scanning
    @State private var showScanner = false
    @State private var scannedCode: String?
    @State private var lookingUpBarcode = false
    @State private var missingBarcode: String?
    @State private var barcodeError: String?

    private enum OnlineState: Equatable {
        case idle, searching, done, failed(String)
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }
    private var customFoods: [FoodItem] { store.customFoods }
    private var recentFoods: [FoodItem] { store.recentFoods }

    private var results: [FoodItem] {
        let library = FoodLibrary.common
        guard !trimmedQuery.isEmpty else { return library }
        return (customFoods + recentFoods + library).filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery) || ($0.brand?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        }
    }

    private var showsOnlineSection: Bool {
        onlineSearchEnabled && foodDatabase.isConfigured && trimmedQuery.count >= 2
    }

    private var selectedCalories: Int { selected.reduce(0) { $0 + $1.calories } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.md) {
                Picker("Meal", selection: $mealType) {
                    ForEach(Meal.MealType.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, VitalaSpacing.sm)

                if !selected.isEmpty {
                    SectionHeader(title: "In this meal", trailing: "\(selectedCalories) kcal")
                    ForEach(FoodGroup.grouping(selected)) { group in
                        SelectedFoodRow(group: group,
                                        onAdd: { selected.append(group.item.newInstance()) },
                                        onRemove: { removeOne(of: group) })
                    }
                }

                if onlineSearchEnabled {
                    actionRow(icon: "barcode.viewfinder", title: "Scan barcode",
                              subtitle: "Point your camera at a packaged food.") {
                        showScanner = true
                    }
                    .accessibilityIdentifier("meal.scanBarcode")
                }
                actionRow(icon: "plus.circle.fill", title: "Add custom food",
                          subtitle: "Can't find it? Create your own.") {
                    showCustomSheet = true
                }
                .accessibilityIdentifier("meal.customFood")

                if !customFoods.isEmpty && query.isEmpty {
                    SectionHeader(title: "Your foods")
                    ForEach(customFoods) { item in
                        foodButton(item, isCustom: true)
                    }
                }

                if !recentFoods.isEmpty && query.isEmpty {
                    SectionHeader(title: "Recent")
                    ForEach(recentFoods.prefix(8)) { item in
                        foodButton(item, isCustom: false)
                    }
                }

                if showsOnlineSection {
                    onlineSection
                }

                SectionHeader(title: query.isEmpty ? "Common foods" : "Saved and common foods")
                if results.isEmpty {
                    EmptyStateRow(text: showsOnlineSection
                                  ? "Nothing saved matches. Try the food database results above."
                                  : "No matches. Try another word or add a custom food.",
                                  icon: "magnifyingglass")
                }
                ForEach(results) { item in
                    foodButton(item, isCustom: customFoods.contains { $0.id == item.id })
                }

                if editing != nil {
                    SecondaryButton(title: "Delete this meal", icon: "trash", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .padding(.top, VitalaSpacing.sm)
                }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .background(VitalaColor.background.ignoresSafeArea())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
        .bottomActionBar {
            PrimaryButton(title: saveLabel,
                          icon: "checkmark",
                          isLoading: saving,
                          isEnabled: !selected.isEmpty) {
                Task { await save() }
            }
        }
        .navigationTitle(editing == nil ? "Log a meal" : "Edit meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .task(id: trimmedQuery) { await searchOnline() }
        .overlay {
            if lookingUpBarcode {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Looking up product…")
                        .font(VitalaFont.bodyMedium(15))
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
                .liquidGlass(in: Capsule())
                .accessibilityElement(children: .combine)
            }
        }
        .sheet(isPresented: $showScanner, onDismiss: lookUpScannedCode) {
            NavigationStack {
                BarcodeScannerSheet { code in scannedCode = code }
            }
        }
        .alert("Product not found", isPresented: Binding(get: { missingBarcode != nil },
                                                          set: { if !$0 { missingBarcode = nil } })) {
            Button("Add custom food") { showCustomSheet = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text("No nutrition data for barcode \(missingBarcode ?? ""). You can add it as a custom food.")
        }
        .alert("Couldn't look that up", isPresented: Binding(get: { barcodeError != nil },
                                                              set: { if !$0 { barcodeError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(barcodeError ?? "")
        }
        .sheet(item: $portionFor) { result in
            NavigationStack {
                FoodPortionSheet(result: result) { item in
                    selected.append(item)
                    store.rememberRecentFood(item)
                    Haptics.selection()
                    AccessibilityNotification.Announcement("Added \(item.name)").post()
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCustomSheet) {
            NavigationStack {
                CustomFoodSheet { newItem in
                    selected.append(newItem.newInstance())
                }
            }
        }
        .confirmationDialog("Delete this meal?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deleteMeal() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let m = editing {
                mealType = m.type
                selected = m.items
            } else if let initialType {
                mealType = initialType
            }
        }
    }

    private func foodButton(_ item: FoodItem, isCustom: Bool) -> some View {
        Button {
            selected.append(item.newInstance())
            Haptics.selection()
            AccessibilityNotification.Announcement("Added \(item.name)").post()
        } label: {
            FoodRow(item: item)
                .overlay(alignment: .topTrailing) {
                    if isCustom {
                        Text("Custom")
                            .font(VitalaFont.caption(10))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(VitalaColor.primary.opacity(0.14)))
                            .foregroundStyle(VitalaColor.primary)
                            .padding(6)
                    }
                }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(item.fullName), \(item.servingSize), \(item.calories) kilocalories")
        .accessibilityHint("Adds one serving")
        .contextMenu {
            if isCustom {
                Button(role: .destructive) { deleteCustom(item) } label: {
                    Label("Delete custom food", systemImage: "trash")
                }
            }
        }
        .accessibilityActions {
            if isCustom {
                Button("Delete custom food") { deleteCustom(item) }
            }
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VitalaFont.bodyMedium(15))
                    Text(subtitle)
                        .font(VitalaFont.caption(12))
                        .foregroundStyle(VitalaColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(VitalaColor.muted)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(minHeight: 44)
            .foregroundStyle(VitalaColor.primary)
            .background(RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                .fill(VitalaColor.primary.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Barcode

    /// Runs after the scanner sheet has fully closed, so the portion sheet
    /// can present cleanly.
    private func lookUpScannedCode() {
        guard let code = scannedCode else { return }
        scannedCode = nil
        lookingUpBarcode = true
        Task {
            defer { lookingUpBarcode = false }
            do {
                if let found = try await BarcodeLookup().food(barcode: code) {
                    portionFor = found
                } else {
                    missingBarcode = code
                }
            } catch {
                barcodeError = (error as? LocalizedError)?.errorDescription ?? "Try again in a moment."
            }
        }
    }

    // MARK: Online search

    private var onlineSection: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "Food database", trailing: "USDA")
            switch onlineState {
            case .idle, .searching:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching…")
                        .font(VitalaFont.body(14))
                        .foregroundStyle(VitalaColor.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityElement(children: .combine)
            case .failed(let message):
                EmptyStateRow(text: message, icon: "wifi.exclamationmark")
            case .done where online.isEmpty:
                EmptyStateRow(text: "No foods found for \"\(trimmedQuery)\".", icon: "magnifyingglass")
            case .done:
                ForEach(online.prefix(15)) { result in
                    Button {
                        portionFor = result
                    } label: {
                        OnlineFoodRow(result: result)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityHint("Choose an amount to add")
                }
                Text("Nutrition data from USDA FoodData Central.")
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
    }

    private func searchOnline() async {
        let term = trimmedQuery
        guard onlineSearchEnabled, foodDatabase.isConfigured, term.count >= 2 else {
            online = []
            onlineState = .idle
            return
        }
        onlineState = .searching
        // Wait for typing to pause; a newer query cancels this task.
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        do {
            let found = try await foodDatabase.search(term)
            guard !Task.isCancelled else { return }
            online = found
            onlineState = .done
            AccessibilityNotification.Announcement("\(found.count) foods found").post()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            online = []
            onlineState = .failed((error as? LocalizedError)?.errorDescription ?? "Couldn't search right now.")
        }
    }

    private var saveLabel: String {
        if saving { return "Saving…" }
        let base = editing == nil ? "Save meal" : "Save changes"
        return selected.isEmpty ? base : "\(base) · \(selectedCalories) kcal"
    }

    private func removeOne(of group: FoodGroup) {
        if let i = selected.lastIndex(where: { FoodGroup.key($0) == group.id }) {
            selected.remove(at: i)
        }
    }

    private func deleteCustom(_ item: FoodItem) {
        Task { try? await store.deleteCustomFood(item) }
    }

    private func save() async {
        saving = true; defer { saving = false }
        let date: Date = {
            if let m = editing { return m.date }
            guard let target = forDate, !Calendar.current.isDateInToday(target) else {
                return .now
            }
            // For backdated logs anchor to the selected day at the current time.
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: .now)
            return cal.date(bySettingHour: comps.hour ?? 12, minute: comps.minute ?? 0, second: 0, of: target) ?? target
        }()
        let meal = Meal(
            id: editing?.id ?? UUID().uuidString,
            date: date,
            type: mealType,
            items: selected,
            notes: editing?.notes
        )
        try? await store.logMeal(meal)
        Haptics.success()
        dismiss()
    }

    private func deleteMeal() async {
        guard let m = editing else { return }
        try? await store.deleteMeal(m)
        dismiss()
    }
}

private struct SelectedFoodRow: View {
    let group: FoodGroup
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: group.item.displayIcon)
                .foregroundStyle(VitalaColor.primary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.item.fullName).font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(group.item.calories * group.count) kcal · \(Int(group.item.proteinG * Double(group.count)))g protein")
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 4)
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(VitalaColor.coralText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Remove one \(group.item.name)")
            Text("\(group.count)")
                .font(VitalaFont.bodyMedium(16))
                .monospacedDigit()
                .frame(minWidth: 20)
                .accessibilityLabel("\(group.count) servings")
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(VitalaColor.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Add one \(group.item.name)")
        }
        .padding(.leading, 12)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
            .fill(VitalaColor.primary.opacity(0.06)))
    }
}

private struct OnlineFoodRow: View {
    let result: FoodSearchResult

    private var subtitle: String {
        let portion = result.defaultPortion
        let kcal = Int(result.nutrients(for: portion, quantity: 1).kcal.rounded())
        let base = "\(kcal) kcal per \(portion.label)"
        return result.brand.map { "\($0) · \(base)" } ?? base
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.isBranded ? "barcode" : "leaf.fill")
                .foregroundStyle(VitalaColor.primary)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VitalaColor.primary.opacity(0.10)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name).font(VitalaFont.bodyMedium(15)).foregroundStyle(VitalaColor.textPrimary)
                Text(subtitle).font(VitalaFont.caption(13)).foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(VitalaColor.primary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .frame(minHeight: 44)
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}
