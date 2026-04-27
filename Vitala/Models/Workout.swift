import Foundation

struct Workout: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var category: Category
    var durationMinutes: Int
    var caloriesBurned: Int
    var difficulty: Difficulty
    var imageSystemName: String   // SF Symbol used as artwork placeholder
    var coverTint: String         // hex string
    var exercises: [Exercise]
    var createdAt: Date = .now

    enum Category: String, Codable, CaseIterable, Identifiable {
        case yoga, strength, cardio, hiit, pilates, mobility, walking, running
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .yoga: "figure.yoga"
            case .strength: "dumbbell.fill"
            case .cardio: "heart.circle.fill"
            case .hiit: "bolt.heart.fill"
            case .pilates: "figure.pilates"
            case .mobility: "figure.flexibility"
            case .walking: "figure.walk"
            case .running: "figure.run"
            }
        }
    }

    enum Difficulty: String, Codable, CaseIterable, Identifiable {
        case beginner, intermediate, advanced
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }
}

struct Exercise: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var seconds: Int
    var reps: Int?
    var sets: Int?
    var instructions: String
    var icon: String
}

/// A logged workout session. Persisted to Firestore.
struct WorkoutSession: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var workoutId: String
    var workoutName: String
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int
    var caloriesBurned: Int
    var notes: String?
}

/// Sample library shipped with the app for offline / first-launch use.
enum WorkoutLibrary {
    static let all: [Workout] = [
        Workout(
            name: "Morning Sun Salutation",
            category: .yoga,
            durationMinutes: 15,
            caloriesBurned: 90,
            difficulty: .beginner,
            imageSystemName: "sun.max.fill",
            coverTint: "#F4C28A",
            exercises: [
                .init(name: "Mountain pose", seconds: 30, reps: nil, sets: nil,
                      instructions: "Stand tall, weight even on both feet, palms in.",
                      icon: "figure.stand"),
                .init(name: "Forward fold", seconds: 45, reps: nil, sets: nil,
                      instructions: "Hinge at the hips, let arms hang heavy.",
                      icon: "figure.flexibility"),
                .init(name: "Plank to up-dog", seconds: 60, reps: nil, sets: nil,
                      instructions: "Flow through plank, lower halfway, rise into up-dog.",
                      icon: "figure.core.training"),
                .init(name: "Down dog", seconds: 45, reps: nil, sets: nil,
                      instructions: "Press through palms, hips back and up.",
                      icon: "figure.yoga"),
                .init(name: "Childs pose", seconds: 60, reps: nil, sets: nil,
                      instructions: "Knees wide, big toes touching, melt your chest down.",
                      icon: "figure.mind.and.body")
            ]
        ),
        Workout(
            name: "Full Body Strength",
            category: .strength,
            durationMinutes: 30,
            caloriesBurned: 240,
            difficulty: .intermediate,
            imageSystemName: "dumbbell.fill",
            coverTint: "#88B5A6",
            exercises: [
                .init(name: "Goblet squat", seconds: 0, reps: 12, sets: 3,
                      instructions: "Hold weight at chest, sit hips back and down.",
                      icon: "figure.strengthtraining.functional"),
                .init(name: "Push-up", seconds: 0, reps: 10, sets: 3,
                      instructions: "Hands under shoulders, body in one line.",
                      icon: "figure.strengthtraining.traditional"),
                .init(name: "Bent-over row", seconds: 0, reps: 10, sets: 3,
                      instructions: "Hinge at hips, pull elbows past ribs.",
                      icon: "figure.strengthtraining.functional"),
                .init(name: "Reverse lunge", seconds: 0, reps: 10, sets: 3,
                      instructions: "Step back, drop the trailing knee softly.",
                      icon: "figure.walk")
            ]
        ),
        Workout(
            name: "HIIT Spark",
            category: .hiit,
            durationMinutes: 20,
            caloriesBurned: 260,
            difficulty: .advanced,
            imageSystemName: "bolt.heart.fill",
            coverTint: "#E8806E",
            exercises: [
                .init(name: "Jump squats", seconds: 40, reps: nil, sets: 4,
                      instructions: "Explode up, soft landing.", icon: "figure.run"),
                .init(name: "Mountain climbers", seconds: 40, reps: nil, sets: 4,
                      instructions: "Drive knees in fast, hips low.", icon: "figure.core.training"),
                .init(name: "Burpees", seconds: 40, reps: nil, sets: 4,
                      instructions: "Down, plank, jump up.", icon: "figure.cross.training"),
                .init(name: "Rest", seconds: 20, reps: nil, sets: 4,
                      instructions: "Breathe slow.", icon: "leaf")
            ]
        ),
        Workout(
            name: "Recovery Mobility",
            category: .mobility,
            durationMinutes: 12,
            caloriesBurned: 60,
            difficulty: .beginner,
            imageSystemName: "figure.flexibility",
            coverTint: "#88B5A6",
            exercises: [
                .init(name: "Cat-cow", seconds: 60, reps: nil, sets: nil,
                      instructions: "On all fours, alternate spinal flex / extension.",
                      icon: "figure.mind.and.body"),
                .init(name: "Hip openers", seconds: 60, reps: nil, sets: nil,
                      instructions: "Pigeon stretch, breathe deep.", icon: "figure.yoga"),
                .init(name: "Thoracic twist", seconds: 60, reps: nil, sets: nil,
                      instructions: "Open chest to ceiling.", icon: "figure.flexibility")
            ]
        ),
        Workout(
            name: "Easy Run",
            category: .running,
            durationMinutes: 25,
            caloriesBurned: 220,
            difficulty: .beginner,
            imageSystemName: "figure.run",
            coverTint: "#2F6B5C",
            exercises: [
                .init(name: "Warm-up walk", seconds: 180, reps: nil, sets: nil,
                      instructions: "Brisk walk, find your breath.", icon: "figure.walk"),
                .init(name: "Easy pace run", seconds: 1080, reps: nil, sets: nil,
                      instructions: "Conversational pace.", icon: "figure.run"),
                .init(name: "Cool down", seconds: 240, reps: nil, sets: nil,
                      instructions: "Walk, then gentle stretch.", icon: "figure.cooldown")
            ]
        )
    ]
}
