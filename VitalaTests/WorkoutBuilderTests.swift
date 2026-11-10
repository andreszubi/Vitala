import Foundation
import Testing
@testable import Vitala

@MainActor
struct WorkoutBuilderTests {
    private func exercise(_ name: String) throws -> Exercise {
        try #require(ExerciseLibrary.all.first { $0.exercise.name == name }).exercise
    }

    @Test func everyLibraryExerciseIsListedOnceAndHasADemonstration() {
        let names = ExerciseLibrary.all.map(\.exercise.name)
        #expect(Set(names).count == names.count)
        #expect(Set(ExerciseLibrary.all.map(\.id)).count == names.count)
        for name in names {
            #expect(ExerciseDemo.named(name) != nil, "\(name) has no demonstration")
        }
        // Everything in the shipped workouts can be reused.
        for workout in WorkoutLibrary.all {
            for shipped in workout.exercises { #expect(names.contains(shipped.name)) }
        }
        #expect(names.contains("Squat") && names.contains("Plank"))
        #expect(!ExerciseLibrary.categories.isEmpty)
    }

    @Test func lengthComesFromTheExercises() throws {
        var plank = try exercise("Plank")
        plank.seconds = 45
        plank.sets = 4                       // 180 s
        var squat = try exercise("Squat")
        squat.reps = 10
        squat.sets = 3                       // 3 × 30 s + 2 rests of 30 s = 150 s
        var run = try exercise("Jog on the spot")
        run.seconds = 90
        run.sets = nil                       // 90 s
        #expect(plank.estimatedSeconds == 180)
        #expect(squat.estimatedSeconds == 150)
        #expect(Workout.estimatedMinutes(for: [plank, squat, run]) == 7)
        #expect(Workout.estimatedMinutes(for: []) == 1, "never zero, so progress can't divide by it")
    }

    @Test func energyScalesWithEffortTimeAndWeight() {
        #expect(Workout.estimatedCalories(category: .hiit, minutes: 20, weightKg: 70) == 210)
        #expect(Workout.estimatedCalories(category: .yoga, minutes: 20, weightKg: 70) == 70)
        #expect(Workout.estimatedCalories(category: .hiit, minutes: 20, weightKg: 90) == 270)
        // No weight on the profile, or a nonsense one: assume 70 kg.
        #expect(Workout.estimatedCalories(category: .hiit, minutes: 20, weightKg: nil) == 210)
        #expect(Workout.estimatedCalories(category: .hiit, minutes: 20, weightKg: 0) == 210)
    }

    @Test func theSameExerciseTwiceGetsTwoIds() throws {
        let squat = try exercise("Squat")
        let built = Workout.custom(name: "Legs", category: .strength, difficulty: .intermediate,
                                   exercises: [squat, try exercise("Rest"), squat], weightKg: 62)
        #expect(built.isCustom)
        #expect(Set(built.exercises.map(\.id)).count == 3)
        #expect(built.exercises.map(\.name) == ["Squat", "Rest", "Squat"])
        #expect(built.durationMinutes == Workout.estimatedMinutes(for: built.exercises))
        #expect(built.imageSystemName == Workout.Category.strength.icon)
        #expect(!WorkoutLibrary.all.contains { $0.isCustom })
    }

    @Test func builtWorkoutsAreSavedEditedAndDeleted() throws {
        let files = SecureFileStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("VitalaBuilder-\(UUID().uuidString)", isDirectory: true))
        let defaults = UserDefaults(suiteName: "VitalaBuilder-\(UUID().uuidString)")!
        let store = DataStore(files: files, defaults: defaults)
        let built = Workout.custom(name: "Morning circuit", category: .hiit, difficulty: .beginner,
                                   exercises: [try exercise("Burpees"), try exercise("Plank")], weightKg: nil)
        store.saveCustomWorkout(built)

        // Editing keeps the id, so logged sessions still point at it.
        let edited = Workout.custom(id: built.id, name: "Morning circuit", category: .hiit, difficulty: .advanced,
                                    exercises: built.exercises + [try exercise("Rest")], weightKg: nil)
        store.saveCustomWorkout(edited)
        #expect(store.customWorkouts.count == 1)
        store.flush()

        let relaunched = DataStore(files: files, defaults: defaults)
        #expect(relaunched.customWorkouts.first?.exercises.count == 3)
        #expect(relaunched.customWorkouts.first?.difficulty == .advanced)
        relaunched.deleteCustomWorkout(edited)
        relaunched.flush()
        #expect(DataStore(files: files, defaults: defaults).customWorkouts.isEmpty)
    }
}
