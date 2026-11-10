import Foundation

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
