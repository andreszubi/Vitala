import Foundation

/// A single sample of a health metric (step count, heart rate, etc.).
struct HealthMetric: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: Kind
    var value: Double
    var unit: String
    var date: Date

    enum Kind: String, Codable, CaseIterable {
        case steps, activeEnergy, restingEnergy, heartRate, restingHR
        case bodyMass, sleepHours, mindfulMinutes, distanceWalkingRunning, exerciseMinutes
    }
}

/// Daily roll-up displayed on the dashboard.
struct DailySummary: Codable, Hashable {
    var date: Date
    var steps: Int = 0
    var activeKcal: Int = 0
    var exerciseMinutes: Int = 0
    var standHours: Int = 0
    var heartRate: Int? = nil
    var sleepHours: Double = 0
    var waterMl: Int = 0
    var distanceKm: Double = 0
    var mindfulMinutes: Int = 0
}
