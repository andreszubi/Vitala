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
    /// Asking for a name to save the foods in this meal under.
    @State private var namingSavedMeal = false
    @State private var savedMealName = ""

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
    private var favouriteFoods: [FoodItem] { store.favouriteFoods }

    private var results: [FoodItem] {
        let library = FoodLibrary.common
        guard !trimmedQuery.isEmpty else { return library }
        // A favourite is usually also a recent or common food: list it once.
        var seen = Set<String>()
        return (favouriteFoods + customFoods + recentFoods + library).filter {
            ($0.name.localizedCaseInsensitiveContains(trimmedQuery)
                || ($0.brand?.localizedCaseInsensitiveContains(trimmedQuery) ?? false))
                && seen.insert(FoodGroup.key($0)).inserted
        }
    }

    /// The day this meal is being logged for.
    private var targetDay: Date { editing?.date ?? forDate ?? .now }

    /// What was eaten for this meal the day before, offered while the meal
    /// is still empty.
    private var yesterdaysFoods: [FoodItem] {
        guard editing == nil, selected.isEmpty, query.isEmpty else { return [] }
        return Meal.eaten(mealType, theDayBefore: targetDay, in: store.meals)
    }

    private var showsOnlineSection: Bool {
        onlineSearchEnabled && foodDatabase.isConfigured && trimmedQuery.count >= 2
    }

    /// The chain whose whole menu is being browsed, when the search is its name.
    private var browsingChain: RestaurantChain? { RestaurantChain.matching(trimmedQuery) }

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
                                        isFavourite: store.isFavourite(group.item),
                                        onAdd: { selected.append(group.item.newInstance()) },
                                        onRemove: { removeOne(of: group) },
                                        onToggleFavourite: { toggleFavourite(group.item) })
                    }
                    Button {
                        savedMealName = "My usual \(mealType.label.lowercased())"
                        namingSavedMeal = true
                    } label: {
                        Label("Save as a usual meal", systemImage: "bookmark")
                            .font(VitalaFont.bodyMedium(15))
                            .foregroundStyle(VitalaColor.primary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Keeps these foods together to log again in one tap")
                }

                if !yesterdaysFoods.isEmpty {
                    let foods = yesterdaysFoods
                    actionRow(icon: "arrow.uturn.backward.circle.fill",
                              title: "Same as yesterday",
                              subtitle: "\(SavedMeal(name: "", items: foods).summary) · \(foods.reduce(0) { $0 + $1.calories }) kcal") {
                        selected.append(contentsOf: foods)
                        Haptics.selection()
                        AccessibilityNotification.Announcement("Added yesterday's \(mealType.label.lowercased())").post()
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

                if onlineSearchEnabled && foodDatabase.isConfigured && query.isEmpty {
                    restaurantsRow
                }

                if !store.savedMeals.isEmpty && query.isEmpty {
                    SectionHeader(title: "Your meals")
                    ForEach(store.savedMeals) { meal in
                        savedMealButton(meal)
                    }
                }

                if !favouriteFoods.isEmpty && query.isEmpty {
                    SectionHeader(title: "Favourites")
                    ForEach(favouriteFoods) { item in
                        foodButton(item, isCustom: false)
                    }
                }

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
        // Nothing else can be opened while a scan is being looked up, so
        // its result never has to queue behind another sheet.
        .allowsHitTesting(!lookingUpBarcode)
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
        .alert("Save as a usual meal", isPresented: $namingSavedMeal) {
            TextField("Name", text: $savedMealName)
            Button("Save") { saveUsualMeal() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will be listed under Your meals whenever you log food.")
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
        let starred = store.isFavourite(item)
        return HStack(spacing: 2) {
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
            FavouriteButton(isOn: starred, name: item.name) { toggleFavourite(item) }
        }
    }

    private func savedMealButton(_ meal: SavedMeal) -> some View {
        Button {
            selected.append(contentsOf: meal.items.map { $0.newInstance() })
            Haptics.selection()
            AccessibilityNotification.Announcement("Added \(meal.name)").post()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(VitalaColor.primary)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VitalaColor.primary.opacity(0.10)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name).font(VitalaFont.bodyMedium(15)).foregroundStyle(VitalaColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(meal.summary).font(VitalaFont.caption(13)).foregroundStyle(VitalaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text("\(meal.totalCalories) kcal").font(VitalaFont.bodyMedium(14))
                    .foregroundStyle(VitalaColor.textPrimary)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            .frame(minHeight: 44)
            .surfaceCard()
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint("Adds every food in it")
        .contextMenu {
            Button(role: .destructive) { store.deleteSavedMeal(meal) } label: {
                Label("Delete saved meal", systemImage: "trash")
            }
        }
        .accessibilityActions {
            Button("Delete saved meal") { store.deleteSavedMeal(meal) }
        }
    }

    private func toggleFavourite(_ item: FoodItem) {
        let starred = store.toggleFavourite(item)
        Haptics.selection()
        AccessibilityNotification.Announcement(starred ? "Added to favourites" : "Removed from favourites").post()
    }

    private func saveUsualMeal() {
        let name = savedMealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty else { return }
        store.saveMeal(SavedMeal(name: name.isEmpty ? "My usual \(mealType.label.lowercased())" : name,
                                 items: selected.map { $0.newInstance() }))
        Haptics.success()
        AccessibilityNotification.Announcement("Saved to your meals").post()
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

    /// Chains whose menu items USDA lists. Tapping one searches for its name,
    /// which lists its whole menu; adding a word ("fries") narrows it.
    private var restaurantsRow: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "Restaurants")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RestaurantChain.all) { chain in
                        FilterChip(label: chain.name, isOn: false) { query = chain.name }
                            .accessibilityHint("Shows menu items")
                    }
                }
                .glassGroup()
                .padding(.vertical, 2)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Restaurants")
        }
    }

    private var onlineSection: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: browsingChain.map { "\($0.name) menu" } ?? "Food database",
                          trailing: browsingChain != nil && onlineState == .done && !online.isEmpty
                            ? "\(online.count) \(online.count == 1 ? "item" : "items")" : "USDA")
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
                // A chain's menu is listed in full; a general search shows the best matches.
                ForEach(online.prefix(browsingChain == nil ? 15 : 200)) { result in
                    Button {
                        portionFor = result
                    } label: {
                        OnlineFoodRow(result: result)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityHint("Choose an amount to add")
                }
                Text(online.contains(where: \.isRestaurant)
                     ? "Nutrition data from USDA FoodData Central. Restaurant items were analysed by USDA and may differ from today's menus."
                     : "Nutrition data from USDA FoodData Central.")
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

/// A star that adds a food to favourites or takes it out again.
struct FavouriteButton: View {
    let isOn: Bool
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "star.fill" : "star")
                .font(.body)
                .foregroundStyle(isOn ? VitalaColor.primary : VitalaColor.muted)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Remove \(name) from favourites" : "Add \(name) to favourites")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private struct SelectedFoodRow: View {
    let group: FoodGroup
    let isFavourite: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onToggleFavourite: () -> Void

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
        .contextMenu {
            Button(action: onToggleFavourite) {
                Label(isFavourite ? "Remove from favourites" : "Add to favourites",
                      systemImage: isFavourite ? "star.slash" : "star")
            }
        }
        .accessibilityAction(named: isFavourite ? "Remove from favourites" : "Add to favourites",
                             onToggleFavourite)
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
            Image(systemName: result.isRestaurant ? "takeoutbag.and.cup.and.straw.fill"
                              : result.isBranded ? "basket.fill" : "leaf.fill")
                .foregroundStyle(VitalaColor.primary)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VitalaColor.primary.opacity(0.10)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name).font(VitalaFont.bodyMedium(15)).foregroundStyle(VitalaColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
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
