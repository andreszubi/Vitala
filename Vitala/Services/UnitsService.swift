import Foundation
import SwiftUI

enum UnitSystem: String, CaseIterable, Identifiable, Codable {
    case metric, imperial
    var id: String { rawValue }
    var label: String {
        switch self {
        case .metric: "Metric (kg, cm, ml, km)"
        case .imperial: "Imperial (lb, ft/in, fl oz, mi)"
        }
    }
    var shortLabel: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }
}

/// Single source of truth for the user's measurement system.
/// All data models stay in metric; this service converts at the display + input layer.
@MainActor
final class UnitsService: ObservableObject {
    @AppStorage("vitala.units") private var stored: String = UnitSystem.metric.rawValue

    var system: UnitSystem {
        get { UnitSystem(rawValue: stored) ?? .metric }
        set {
            stored = newValue.rawValue
            objectWillChange.send()
        }
    }

    // MARK: Weight

    /// Format kg in the user's preferred unit (e.g. "70 kg" or "154 lb").
    func formatWeight(kg: Double, decimals: Int = 0) -> String {
        switch system {
        case .metric:
            return String(format: "%.\(decimals)f kg", kg)
        case .imperial:
            return String(format: "%.\(decimals)f lb", kg * 2.2046226218)
        }
    }

    func weightUnitLabel() -> String { system == .metric ? "kg" : "lb" }

    /// Parse user input ("154" or "70") in the current system back to kg.
    func parseWeightToKg(_ text: String) -> Double? {
        guard let v = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return system == .metric ? v : v / 2.2046226218
    }

    /// Convert kg -> display value (kg or lb).
    func displayWeight(kg: Double) -> Double {
        system == .metric ? kg : kg * 2.2046226218
    }

    // MARK: Height

    /// Format cm as either "172 cm" or "5'8\"".
    func formatHeight(cm: Double) -> String {
        switch system {
        case .metric:
            return String(format: "%.0f cm", cm)
        case .imperial:
            let totalInches = cm / 2.54
            let feet = Int(totalInches) / 12
            let inches = Int(totalInches.rounded()) % 12
            return "\(feet)' \(inches)\""
        }
    }

    func heightUnitLabel() -> String { system == .metric ? "cm" : "ft / in" }

    func parseHeightToCm(metric metricText: String, feet: String, inches: String) -> Double? {
        switch system {
        case .metric:
            return Double(metricText.replacingOccurrences(of: ",", with: "."))
        case .imperial:
            let f = Double(feet) ?? 0
            let i = Double(inches) ?? 0
            let totalIn = f * 12 + i
            return totalIn * 2.54
        }
    }

    func cmToFeetInches(_ cm: Double) -> (feet: Int, inches: Int) {
        let total = cm / 2.54
        let feet = Int(total) / 12
        let inches = Int(total.rounded()) % 12
        return (feet, inches)
    }

    // MARK: Volume (water)

    /// Format ml as "500 ml" or "17 fl oz".
    func formatVolume(ml: Double, decimals: Int = 0) -> String {
        switch system {
        case .metric:
            return String(format: "%.\(decimals)f ml", ml)
        case .imperial:
            return String(format: "%.\(decimals)f fl oz", ml * 0.033814)
        }
    }

    func volumeUnitLabel() -> String { system == .metric ? "ml" : "fl oz" }

    /// Quick-add water amounts in the current unit system, with the underlying ml value.
    /// Returned tuples are (display label, ml value).
    func quickWaterOptions() -> [(label: String, ml: Int)] {
        switch system {
        case .metric:
            return [(150, 150), (250, 250), (350, 350), (500, 500), (750, 750)]
                .map { (label: "\($0.0) ml", ml: $0.1) }
        case .imperial:
            // Common cup/bottle sizes
            return [
                (label: "6 fl oz",  ml: 177),
                (label: "8 fl oz",  ml: 237),
                (label: "12 fl oz", ml: 355),
                (label: "16 fl oz", ml: 473),
                (label: "24 fl oz", ml: 710)
            ]
        }
    }

    // MARK: Distance

    /// Format km as "5.0 km" or "3.1 mi".
    func formatDistance(km: Double, decimals: Int = 1) -> String {
        switch system {
        case .metric:
            return String(format: "%.\(decimals)f km", km)
        case .imperial:
            return String(format: "%.\(decimals)f mi", km * 0.621371)
        }
    }

    func distanceUnitLabel() -> String { system == .metric ? "km" : "mi" }
}
