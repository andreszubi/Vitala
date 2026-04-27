import Foundation

/// User profile stored in Firestore. Mirrors the auth user with extra wellness fields.
struct UserProfile: Codable, Identifiable, Hashable {
    var id: String                  // Firebase Auth UID
    var email: String
    var displayName: String
    var avatarURL: String?
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
    var dailyCalories: Int = 2_200
    var dailyWaterMl: Int = 2_000
    var weeklyWorkouts: Int = 4
    var sleepHours: Double = 8.0
    var weightTargetKg: Double? = nil
    var primaryFocus: Focus = .balanced

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
