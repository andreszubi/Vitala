import Charts
import SwiftUI

/// Describes a per-day bar chart to VoiceOver as an Audio Graph, so people
/// can hear the shape of the data and step through values.
struct DailyChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let unit: String
    let points: [(Date, Double)]
    var goal: Double? = nil

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = points.map { $0.0.formatted(.dateTime.weekday(.abbreviated).month().day()) }
        let maxValue = max(points.map(\.1).max() ?? 0, goal ?? 0, 1)
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Day", categoryOrder: labels)
        let yAxis = AXNumericDataAxisDescriptor(title: title, range: 0...maxValue,
                                                gridlinePositions: goal.map { [$0] } ?? []) { value in
            "\(Int(value.rounded())) \(unit)"
        }
        let series = AXDataSeriesDescriptor(name: title, isContinuous: false,
                                            dataPoints: zip(labels, points).map { AXDataPoint(x: $0, y: $1.1) })
        return AXChartDescriptor(title: title, summary: summary, xAxis: xAxis, yAxis: yAxis,
                                 additionalAxes: [], series: [series])
    }

    var summary: String {
        let logged = points.filter { $0.1 > 0 }
        guard let best = logged.max(by: { $0.1 < $1.1 }) else { return "No data yet." }
        let average = logged.reduce(0) { $0 + $1.1 } / Double(logged.count)
        var text = "Average \(Int(average.rounded())) \(unit) on \(logged.count) of \(points.count) days. "
        text += "Highest \(Int(best.1.rounded())) \(unit) on \(best.0.formatted(.dateTime.weekday(.wide)))."
        if let goal {
            let met = points.filter { $0.1 >= goal }.count
            text += " Goal met on \(met) days."
        }
        return text
    }
}

extension View {
    /// Collapses a chart into one VoiceOver element with a spoken summary and
    /// an Audio Graph.
    func dailyChartAccessibility(_ descriptor: DailyChartDescriptor) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(descriptor.title) chart")
            .accessibilityValue(descriptor.summary)
            .accessibilityChartDescriptor(descriptor)
    }
}
