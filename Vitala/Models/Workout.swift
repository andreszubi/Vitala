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

    enum Category: String, Codable, CaseIterable, Identifiable {
        case yoga, strength, cardio, hiit, pilates, mobility, walking, running
        var id: String { rawValue }
        var label: String {
            switch self {
            case .hiit: "HIIT"
            default: rawValue.capitalized
            }
        }
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

    /// "3 × 12 reps", "4 × 40 sec" or "1 min"; nil when nothing is prescribed.
    var prescription: String? {
        if seconds > 0 {
            let time = seconds >= 60 ? "\(seconds / 60) min" : "\(seconds) sec"
            if let sets, sets > 1 { return "\(sets) × \(time)" }
            return time
        }
        if let sets, let reps { return "\(sets) × \(reps) reps" }
        if let reps { return "\(reps) reps" }
        return nil
    }
}

extension Exercise {
    /// Roughly how long the exercise takes as prescribed: its time for a
    /// timed one; about three seconds a rep, with half a minute's rest
    /// between sets, for a counted one.
    var estimatedSeconds: Int {
        let rounds = max(1, sets ?? 1)
        if seconds > 0 { return seconds * rounds }
        if let reps { return reps * 3 * rounds + 30 * (rounds - 1) }
        return 60
    }
}

extension Workout {
    /// Built by the user rather than shipped with the app.
    var isCustom: Bool { id.hasPrefix(Self.customPrefix) }
    static let customPrefix = "custom."

    /// A new workout built by the user, with its length and energy worked
    /// out from the exercises in it.
    static func custom(id: String? = nil, name: String, category: Category, difficulty: Difficulty,
                       exercises: [Exercise], weightKg: Double?) -> Workout {
        let id = id ?? customPrefix + UUID().uuidString
        let minutes = estimatedMinutes(for: exercises)
        return Workout(id: id, name: name, category: category, durationMinutes: minutes,
                       caloriesBurned: estimatedCalories(category: category, minutes: minutes, weightKg: weightKg),
                       difficulty: difficulty, imageSystemName: category.icon, coverTint: category.coverTint,
                       exercises: exercises.enumerated().map { index, exercise in
                           // The same exercise can appear twice; each needs its own id.
                           var copy = exercise
                           copy.id = "\(id).\(index).\(ExerciseVideo.fileName(for: exercise.name))"
                           return copy
                       })
    }

    /// Whole minutes to do every exercise as prescribed, at least one.
    static func estimatedMinutes(for exercises: [Exercise]) -> Int {
        let seconds = exercises.reduce(0) { $0 + $1.estimatedSeconds }
        return max(1, Int((Double(seconds) / 60).rounded()))
    }

    /// Energy for a session of this kind, from typical effort (MET) for the
    /// category, the time, and body weight (70 kg when it isn't known).
    static func estimatedCalories(category: Category, minutes: Int, weightKg: Double?) -> Int {
        let weight = weightKg.flatMap { $0 > 0 ? $0 : nil } ?? 70
        return Int((category.typicalMET * weight * Double(minutes) / 60).rounded())
    }
}

extension Workout.Category {
    /// Typical effort, in METs, from the Compendium of Physical Activities.
    var typicalMET: Double {
        switch self {
        case .yoga, .pilates: 3.0
        case .mobility: 2.5
        case .walking: 3.5
        case .strength: 5.0
        case .cardio: 7.0
        case .running: 8.0
        case .hiit: 9.0
        }
    }

    /// Cover colour for a workout the user builds.
    var coverTint: String {
        switch self {
        case .yoga: "#F4C28A"
        case .strength, .mobility: "#88B5A6"
        case .hiit, .cardio: "#E8806E"
        case .pilates: "#B79BC9"
        case .walking, .running: "#2F6B5C"
        }
    }
}

/// A logged workout session.
struct WorkoutSession: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var workoutId: String
    var workoutName: String
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int
    var caloriesBurned: Int
    var notes: String?
    /// Optional so sessions logged before 1.0 still decode.
    var category: Workout.Category? = nil
    var distanceKm: Double? = nil
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
    ].map(\.withFixedIDs)
}

/// Every exercise a workout can be built from: the ones in the shipped
/// workouts plus a few staples, each with a demonstration.
enum ExerciseLibrary {
    struct Entry: Identifiable, Hashable {
        let exercise: Exercise
        let category: Workout.Category
        var id: String { exercise.id }
    }

    static let all: [Entry] = {
        var seen = Set<String>()
        var entries: [Entry] = []
        func add(_ exercise: Exercise, _ category: Workout.Category) {
            guard seen.insert(ExerciseDemo.key(exercise.name)).inserted else { return }
            var copy = exercise
            copy.id = "exercise." + ExerciseVideo.fileName(for: exercise.name)
            entries.append(Entry(exercise: copy, category: category))
        }
        for workout in WorkoutLibrary.all {
            for exercise in workout.exercises { add(exercise, workout.category) }
        }
        add(.init(name: "Squat", seconds: 0, reps: 15, sets: 3,
                  instructions: "Feet shoulder-width, sit hips back and down, chest up.",
                  icon: "figure.strengthtraining.functional"), .strength)
        add(.init(name: "Plank", seconds: 30, reps: nil, sets: 3,
                  instructions: "On hands and toes, body in one line. Breathe.",
                  icon: "figure.core.training"), .strength)
        add(.init(name: "Jog on the spot", seconds: 60, reps: nil, sets: nil,
                  instructions: "Light feet, relaxed shoulders, easy breath.",
                  icon: "figure.run"), .hiit)
        return entries
    }()

    /// The categories that have exercises, in the order they are shown.
    static var categories: [Workout.Category] {
        Workout.Category.allCases.filter { category in all.contains { $0.category == category } }
    }
}

private extension Workout {
    /// The same ids on every launch, so a logged session can always be
    /// matched back to the workout it came from.
    var withFixedIDs: Workout {
        var workout = self
        workout.id = "library." + ExerciseVideo.fileName(for: name)
        workout.exercises = exercises.map {
            var exercise = $0
            exercise.id = workout.id + "." + ExerciseVideo.fileName(for: exercise.name)
            return exercise
        }
        return workout
    }
}
