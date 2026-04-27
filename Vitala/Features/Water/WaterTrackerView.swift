import SwiftUI

struct WaterTrackerView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var health: HealthKitService
    @EnvironmentObject var units: UnitsService
    @Environment(\.dismiss) var dismiss
    @State private var entries: [WaterEntry] = []

    private var goal: Int { auth.profile?.goals.dailyWaterMl ?? 2000 }
    private var total: Int { entries.reduce(0) { $0 + $1.amountMl } }
    private var progress: Double { min(1, Double(total) / Double(goal)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                ScreenHeader(title: "Water", subtitle: "Tiny sips, all day long.")
                    .padding(.top, VitalaSpacing.md)

                VStack(spacing: VitalaSpacing.sm) {
                    ZStack {
                        WaterGlass(progress: progress)
                            .frame(width: 200, height: 240)
                        VStack(spacing: 2) {
                            Text(units.formatVolume(ml: Double(total)))
                                .font(VitalaFont.title(34))
                                .foregroundStyle(VitalaColor.textPrimary)
                            Text("of \(units.formatVolume(ml: Double(goal)))")
                                .font(VitalaFont.caption())
                                .foregroundStyle(VitalaColor.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                SectionHeader(title: "Quick add")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(units.quickWaterOptions(), id: \.label) { option in
                        Button {
                            log(ml: option.ml)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "drop.fill")
                                    .foregroundStyle(Color(red: 0.34, green: 0.62, blue: 0.86))
                                Text(option.label).font(VitalaFont.caption(13))
                                    .foregroundStyle(VitalaColor.textPrimary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(VitalaColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !entries.isEmpty {
                    SectionHeader(title: "Today's log")
                    ForEach(entries.sorted { $0.loggedAt > $1.loggedAt }) { e in
                        HStack {
                            Image(systemName: "drop.fill").foregroundStyle(Color(red: 0.34, green: 0.62, blue: 0.86))
                            Text(units.formatVolume(ml: Double(e.amountMl))).font(VitalaFont.bodyMedium(15))
                            Spacer()
                            Text(e.loggedAt, style: .time).font(VitalaFont.caption())
                                .foregroundStyle(VitalaColor.textSecondary)
                        }
                        .padding(.vertical, 10).padding(.horizontal, 12)
                        .background(VitalaColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.sm))
                    }
                }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .task { await load() }
    }

    private func load() async {
        if let e = try? await FirestoreService.shared.water(on: .now) {
            entries = e
        }
    }

    private func log(ml: Int) {
        let entry = WaterEntry(amountMl: ml, loggedAt: .now)
        entries.append(entry)
        Task {
            try? await FirestoreService.shared.logWater(entry)
        }
        // Fire-and-forget HK write so the UI is responsive even if HK hangs.
        Task.detached { [health] in
            try? await health.logWater(ml: Double(ml))
        }
    }
}

/// Decorative animated glass that fills with water.
struct WaterGlass: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .bottom) {
                // Glass outline
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .stroke(VitalaColor.muted.opacity(0.4), lineWidth: 3)

                // Water level
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.5, green: 0.78, blue: 0.95),
                                 Color(red: 0.27, green: 0.55, blue: 0.84)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(height: max(0, h * CGFloat(progress)))
                    .animation(.easeInOut(duration: 0.8), value: progress)

                // Highlight
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.6), .clear],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5)
            }
            .frame(width: w, height: h)
        }
    }
}
