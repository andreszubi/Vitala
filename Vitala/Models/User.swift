import Foundation

/// The user's on-device profile and wellness goals.
struct UserProfile: Codable, Identifiable, Hashable {
    var id: String
    var displayName: String
    var dateOfBirth: Date?
    var gender: Gender = .unspecified
    var heightCm: Double?
    var weightKg: Double?
    var activityLevel: ActivityLevel = .moderate
    var goals: WellnessGoals = .init()
    var createdAt: Date = .now
    var updatedAt: Date = .now

    enum Gender: String, Codable, CaseIterable, Identifiable {
        case female, male, nonBinary, unspecified
        var id: String { rawValue }
        var label: String {
            switch self {
            case .female: "Female"
            case .male: "Male"
            case .nonBinary: "Non-binary"
            case .unspecified: "Prefer not to say"
            }
        }
    }

    enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
        case sedentary, light, moderate, active, athlete
        var id: String { rawValue }
        var label: String {
            switch self {
            case .sedentary: "Sedentary"
            case .light: "Lightly active"
            case .moderate: "Moderately active"
            case .active: "Very active"
            case .athlete: "Athlete"
            }
        }
        var multiplier: Double {
            switch self {
            case .sedentary: 1.2
            case .light: 1.375
            case .moderate: 1.55
            case .active: 1.725
            case .athlete: 1.9
            }
        }
    }
}

struct WellnessGoals: Codable, Hashable {
    var dailySteps: Int = 10_000
    /// Food intake target.
    var dailyCalories: Int = 2_200
    var dailyWaterMl: Int = 2_000
    var weeklyWorkouts: Int = 4
    var sleepHours: Double = 8.0
    var weightTargetKg: Double? = nil
    var primaryFocus: Focus = .balanced
    /// Move ring: active energy burned.
    var dailyActiveKcal: Int = 450
    /// Exercise ring.
    var dailyExerciseMinutes: Int = 30
    var dailyMindfulMinutes: Int = 10

    init() {}

    /// Decodes goals saved by older versions, filling in any target that
    /// didn't exist yet with its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WellnessGoals()
        dailySteps = try c.decodeIfPresent(Int.self, forKey: .dailySteps) ?? d.dailySteps
        dailyCalories = try c.decodeIfPresent(Int.self, forKey: .dailyCalories) ?? d.dailyCalories
        dailyWaterMl = try c.decodeIfPresent(Int.self, forKey: .dailyWaterMl) ?? d.dailyWaterMl
        weeklyWorkouts = try c.decodeIfPresent(Int.self, forKey: .weeklyWorkouts) ?? d.weeklyWorkouts
        sleepHours = try c.decodeIfPresent(Double.self, forKey: .sleepHours) ?? d.sleepHours
        weightTargetKg = try c.decodeIfPresent(Double.self, forKey: .weightTargetKg)
        primaryFocus = try c.decodeIfPresent(Focus.self, forKey: .primaryFocus) ?? d.primaryFocus
        dailyActiveKcal = try c.decodeIfPresent(Int.self, forKey: .dailyActiveKcal) ?? d.dailyActiveKcal
        dailyExerciseMinutes = try c.decodeIfPresent(Int.self, forKey: .dailyExerciseMinutes) ?? d.dailyExerciseMinutes
        dailyMindfulMinutes = try c.decodeIfPresent(Int.self, forKey: .dailyMindfulMinutes) ?? d.dailyMindfulMinutes
    }

    enum Focus: String, Codable, CaseIterable, Identifiable {
        case loseWeight, buildMuscle, sleepBetter, manageStress, balanced
        var id: String { rawValue }
        var label: String {
            switch self {
            case .loseWeight: "Lose weight"
            case .buildMuscle: "Build muscle"
            case .sleepBetter: "Sleep better"
            case .manageStress: "Manage stress"
            case .balanced: "Stay balanced"
            }
        }
        var icon: String {
            switch self {
            case .loseWeight: "flame.fill"
            case .buildMuscle: "dumbbell.fill"
            case .sleepBetter: "moon.stars.fill"
            case .manageStress: "leaf.fill"
            case .balanced: "heart.fill"
            }
        }
    }
}

extension UserProfile {
    /// Whole years since `dateOfBirth`.
    func age(on date: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let dob = dateOfBirth else { return nil }
        return calendar.dateComponents([.year], from: dob, to: date).year
    }

    /// Daily calorie suggestion: Mifflin–St Jeor resting energy × activity
    /// level, nudged for the primary focus and rounded to 50 kcal. `nil` until
    /// height, weight and birthday are known.
    func suggestedDailyCalories(on date: Date = .now) -> Int? {
        guard let kg = weightKg, let cm = heightCm, let age = age(on: date), age >= 13 else { return nil }
        let sexOffset: Double
        switch gender {
        case .male: sexOffset = 5
        case .female: sexOffset = -161
        case .nonBinary, .unspecified: sexOffset = -78
        }
        let resting = 10 * kg + 6.25 * cm - 5 * Double(age) + sexOffset
        var daily = resting * activityLevel.multiplier
        switch goals.primaryFocus {
        case .loseWeight: daily -= 400
        case .buildMuscle: daily += 250
        default: break
        }
        let rounded = Int((daily / 50).rounded()) * 50
        return min(max(rounded, 1_200), 4_000)
    }

    /// Plausible body measurements, used to validate input.
    static let heightRangeCm: ClosedRange<Double> = 90...250
    static let weightRangeKg: ClosedRange<Double> = 25...300
}
