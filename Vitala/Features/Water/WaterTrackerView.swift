import SwiftUI

/// Today's water. Presented as a sheet; wraps its own NavigationStack so it
/// always has a Done button.
struct WaterTrackerView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var units: UnitsService
    @Environment(\.dismiss) var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var store = DataStore.shared

    @State private var showingCustom = false
    @State private var customAmount = ""

    private var entries: [WaterEntry] {
        store.water
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }
    private var goal: Int { profileStore.profile?.goals.dailyWaterMl ?? 2000 }
    private var total: Int { entries.reduce(0) { $0 + $1.amountMl } }
    private var progress: Double { min(1, Double(total) / Double(max(goal, 1))) }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 2 : 3)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                    glassSummary

                    SectionHeader(title: "Quick add")
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(units.quickWaterOptions(), id: \.label) { option in
                            amountButton(label: option.label, icon: "drop.fill") { log(ml: option.ml) }
                                .accessibilityHint("Adds this amount to today")
                        }
                        amountButton(label: "Custom", icon: "plus") {
                            customAmount = ""
                            showingCustom = true
                        }
                        .accessibilityHint("Adds an amount you type")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Today's log",
                                      trailing: entries.isEmpty ? nil : "\(entries.count) \(entries.count == 1 ? "drink" : "drinks")")
                        if entries.isEmpty {
                            EmptyStateRow(text: "Nothing yet — every sip counts.", icon: "drop")
                        } else {
                            ForEach(entries) { e in
                                LogRow(icon: "drop.fill",
                                       tint: VitalaColor.water,
                                       title: units.formatVolume(ml: Double(e.amountMl)),
                                       subtitle: e.loggedAt.formatted(date: .omitted, time: .shortened),
                                       noun: "water entry",
                                       onDelete: { Task { try? await store.deleteWater(e) } })
                            }
                        }
                    }
                }
                .padding(.horizontal, VitalaSpacing.lg)
                .padding(.vertical, VitalaSpacing.md)
            }
            .sheetBackground()
            .navigationTitle("Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Add water", isPresented: $showingCustom) {
                TextField("Amount in \(units.volumeUnitLabel())", text: $customAmount)
                    .keyboardType(.decimalPad)
                Button("Add") { logCustom() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("How much did you drink, in \(units.volumeUnitLabel())?")
            }
        }
    }

    private var glassSummary: some View {
        ZStack {
            WaterGlass(progress: progress)
                .frame(width: 180, height: 220)
            VStack(spacing: 2) {
                Text(units.compactVolume(ml: total))
                    .font(VitalaFont.title(30))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text("of \(units.compactVolume(ml: goal))")
                    .font(VitalaFont.caption())
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VitalaColor.surface.opacity(0.85)))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(progress * 100)) percent of today's goal")
    }

    private func amountButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(VitalaColor.water)
                    .accessibilityHidden(true)
                Text(label).font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .surfaceCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func log(ml: Int) {
        guard ml > 0 else { return }
        let entry = WaterEntry(amountMl: ml, loggedAt: .now)
        Task { try? await store.logWater(entry) }
        Haptics.success()
        AccessibilityNotification.Announcement("Added \(units.formatVolume(ml: Double(ml)))").post()
    }

    private func logCustom() {
        guard let value = Double(customAmount.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
        let ml = units.system == .metric ? value : value / 0.033814
        log(ml: Int(ml.rounded()))
    }
}

/// Decorative animated glass that fills with water.
struct WaterGlass: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(VitalaColor.water.opacity(0.08))
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(LinearGradient(colors: [VitalaColor.water.opacity(0.55), VitalaColor.water],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: max(0, h * CGFloat(progress)))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: progress)
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .stroke(VitalaColor.water.opacity(0.45), lineWidth: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        }
        .accessibilityHidden(true)
    }
}
