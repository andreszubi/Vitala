import SwiftUI
import Charts

struct ProgressDashboardView: View {
    @State private var range: Range = .week

    enum Range: String, CaseIterable, Identifiable {
        case week, month, year
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    // Mock weekly data for charts
    private var stepData: [(day: String, value: Int)] {
        ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"].enumerated().map { i, d in
            (d, [6800, 9200, 7400, 11_200, 8600, 4_800, 10_400][i])
        }
    }

    private var caloriesData: [(day: String, value: Int)] {
        ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"].enumerated().map { i, d in
            (d, [1_950, 2_100, 1_780, 2_240, 2_000, 2_350, 1_900][i])
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                ScreenHeader(title: "Progress", subtitle: "Showing up beats showing off.")
                    .padding(.top, VitalaSpacing.md)

                Picker("", selection: $range) {
                    ForEach(Range.allCases) { r in
                        Text(r.label).tag(r)
                    }
                }
                .pickerStyle(.segmented)

                stepsCard
                caloriesCard
                consistencyCard
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Steps").font(VitalaFont.headline(18))
                Spacer()
                Text("avg 8,343").font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            }
            Chart(stepData, id: \.day) { row in
                BarMark(x: .value("Day", row.day),
                        y: .value("Steps", row.value))
                    .foregroundStyle(VitalaColor.primary.gradient)
                    .cornerRadius(6)
            }
            .frame(height: 180)
        }
        .vitalaCard()
    }

    private var caloriesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Calories").font(VitalaFont.headline(18))
                Spacer()
                Text("avg 2,046").font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            }
            Chart(caloriesData, id: \.day) { row in
                LineMark(x: .value("Day", row.day),
                         y: .value("kcal", row.value))
                    .foregroundStyle(VitalaColor.coral)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Day", row.day),
                          y: .value("kcal", row.value))
                    .foregroundStyle(VitalaColor.coral)
            }
            .frame(height: 180)
        }
        .vitalaCard()
    }

    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Consistency").font(VitalaFont.headline(18))
            HStack(spacing: 6) {
                ForEach(0..<28, id: \.self) { i in
                    Rectangle()
                        .fill(intensityColor(for: i))
                        .frame(height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            HStack {
                Text("Less").font(VitalaFont.caption(11)).foregroundStyle(VitalaColor.textSecondary)
                Spacer()
                ForEach([0.15, 0.35, 0.6, 0.9], id: \.self) { v in
                    Rectangle()
                        .fill(VitalaColor.primary.opacity(v))
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text("More").font(VitalaFont.caption(11)).foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .vitalaCard()
    }

    private func intensityColor(for index: Int) -> Color {
        let intensities: [Double] = [0.1, 0.3, 0.6, 0.9, 0.5, 0.4, 0.2,
                                     0.7, 0.5, 0.8, 0.6, 0.4, 0.7, 0.3,
                                     0.9, 0.6, 0.4, 0.5, 0.7, 0.8, 0.5,
                                     0.6, 0.4, 0.7, 0.9, 0.3, 0.5, 0.6]
        return VitalaColor.primary.opacity(intensities[index])
    }
}
