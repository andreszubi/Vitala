import Foundation
import Testing
@testable import Vitala

@MainActor
struct GoalPlanTests {
    private func plan(_ focus: WellnessGoals.Focus, sex: UserProfile.Gender = .female, age: Int = 31,
                      height: Double = 168, weight: Double = 70,
                      activity: UserProfile.ActivityLevel = .moderate, target: Double? = nil) -> GoalPlan {
        GoalPlan(focus: focus, sex: sex, age: age, heightCm: height, weightKg: weight,
                 activity: activity, targetWeightKg: target)
    }

    @Test func energyComesFromBodyAndActivity() {
        // Mifflin–St Jeor: 10 × 70 + 6.25 × 168 − 5 × 31 − 161 = 1,434.
        let balanced = plan(.balanced)
        #expect(balanced.restingCalories == 1_434)
        #expect(balanced.maintenanceCalories == 2_200)      // × 1.55, to the nearest 50
        #expect(balanced.calories == 2_200)
        #expect(abs(balanced.weeklyChangeKg) < 0.001)
        // Men use more at the same size; so do taller, heavier and more active people.
        #expect(plan(.balanced, sex: .male).calories > balanced.calories)
        #expect(plan(.balanced, height: 185).calories > balanced.calories)
        #expect(plan(.balanced, weight: 90).calories > balanced.calories)
        #expect(plan(.balanced, activity: .active).calories > balanced.calories)
        #expect(plan(.balanced, age: 60).calories < balanced.calories)
    }

    @Test func losingWeightIsAModerateDeficit() {
        let losing = plan(.loseWeight)
        // 20% of 2,223 is 445, less than the 500 cap.
        #expect(losing.calories == 1_800)
        #expect(losing.weeklyChangeKg < -0.3 && losing.weeklyChangeKg > -0.5)
        // A larger body gets the 500 kcal cap, never more.
        let larger = plan(.loseWeight, sex: .male, height: 185, weight: 120, activity: .active)
        #expect(larger.maintenanceCalories - larger.calories == 500)
        #expect(larger.weeklyChangeKg > -0.46)
    }

    @Test func foodEnergyNeverGoesBelowTheFloor() {
        let small = plan(.loseWeight, sex: .female, age: 70, height: 150, weight: 45, activity: .sedentary)
        #expect(small.calories == 1_200)
        #expect(plan(.loseWeight, sex: .male, age: 70, height: 155, weight: 48, activity: .sedentary).calories == 1_500)
        #expect(plan(.loseWeight, sex: .unspecified, age: 70, height: 150, weight: 45, activity: .sedentary).calories == 1_350)
        // At the floor the plan says what it will really do: little or no loss.
        #expect(small.weeklyChangeKg > -0.2)
    }

    @Test func buildingMuscleIsASmallSurplusAndMoreProtein() {
        let building = plan(.buildMuscle)
        #expect(building.calories == 2_450)
        #expect(building.weeklyChangeKg > 0)
        #expect(building.proteinG == 125)          // 1.8 g per kg
        #expect(plan(.balanced).proteinG == 70)    // 1.0 g per kg
        #expect(plan(.loseWeight).proteinG == 110) // 1.6 g per kg
    }

    @Test func aReachedTargetHoldsWeightSteady() {
        let reached = plan(.loseWeight, weight: 64, target: 65)
        #expect(reached.targetReached)
        #expect(reached.calories == reached.maintenanceCalories)
        let onTheWay = plan(.loseWeight, weight: 70, target: 65)
        #expect(!onTheWay.targetReached)
        #expect(onTheWay.calories < onTheWay.maintenanceCalories)
        // When losing, protein is set for the weight being aimed at.
        #expect(onTheWay.proteinG == 105)
        #expect(plan(.buildMuscle, weight: 70, target: 68).targetReached)
        #expect(!plan(.buildMuscle, weight: 70, target: 75).targetReached)
    }

    @Test func stepsFollowHeightAndFocus() {
        // The same distance takes a shorter person more steps.
        #expect(plan(.loseWeight, height: 155).steps > plan(.loseWeight, height: 190).steps)
        #expect(plan(.loseWeight).steps == 10_000)
        #expect(plan(.loseWeight).steps > plan(.manageStress).steps)
        #expect(plan(.balanced, age: 70).steps < plan(.balanced).steps)
        for height in stride(from: 100.0, through: 240, by: 20) {
            let steps = plan(.loseWeight, height: height).steps
            #expect((4_000...15_000).contains(steps) && steps % 500 == 0)
        }
    }

    @Test func moveWaterAndSleepFollowTheBody() {
        #expect(plan(.loseWeight, weight: 90).activeKcal > plan(.loseWeight, weight: 60).activeKcal)
        #expect(plan(.loseWeight).activeKcal == 490)
        #expect(plan(.balanced).waterMl == 2_300)       // 33 ml per kg
        #expect(plan(.loseWeight).waterMl == 2_700)     // plus more for training
        #expect(plan(.balanced, weight: 200).waterMl == 4_000)
        #expect(plan(.balanced, age: 16).sleepHours == 9)
        #expect(plan(.balanced, age: 40).sleepHours == 8)
        #expect(plan(.balanced, age: 70).sleepHours == 7.5)
        #expect(plan(.manageStress).mindfulMinutes > plan(.loseWeight).mindfulMinutes)
    }

    @Test func everyPlanStaysWithinWhatTheGoalsScreenAllows() {
        for focus in WellnessGoals.Focus.allCases {
            for sex in UserProfile.Gender.allCases {
                for weight in [30.0, 55, 80, 140, 290] {
                    for height in [95.0, 150, 175, 210, 245] {
                        let p = plan(focus, sex: sex, age: 45, height: height, weight: weight)
                        #expect((1_200...4_000).contains(p.calories))
                        #expect((40...220).contains(p.proteinG))
                        #expect((200...900).contains(p.activeKcal))
                        #expect((1_500...4_000).contains(p.waterMl))
                        #expect((10...120).contains(p.exerciseMinutes))
                    }
                }
            }
        }
    }

    @Test func aProfileNeedsHeightWeightAndBirthdayForAPlan() {
        var profile = UserProfile(id: "1", displayName: "Sam")
        #expect(profile.plan() == nil)
        profile.heightCm = 175
        profile.weightKg = 80
        #expect(profile.plan() == nil)
        profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -40, to: .now)
        #expect(profile.plan() != nil)
        profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -10, to: .now)
        #expect(profile.plan() == nil, "no plans for children")
    }

    @Test func targetsFollowTheProfileWhenLeftToVitala() async throws {
        let files = SecureFileStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("VitalaPlan-\(UUID().uuidString)", isDirectory: true))
        let defaults = UserDefaults(suiteName: "VitalaPlan-\(UUID().uuidString)")!
        let store = ProfileStore(files: files, defaults: defaults)
        store.createProfile(displayName: "Sam")
        var profile = try #require(store.profile)
        #expect(profile.goals.followsPlan, "new profiles leave the targets to Vitala")
        profile.gender = .male
        profile.heightCm = 180
        profile.weightKg = 95
        profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -35, to: .now)
        profile.goals.primaryFocus = .loseWeight
        try await store.saveProfile(profile)
        let heavier = try #require(store.profile?.goals)
        #expect(heavier.dailyCalories == profile.plan()?.calories)

        // Ten kilos lighter: less energy needed, less protein, less to move.
        profile = try #require(store.profile)
        profile.weightKg = 85
        try await store.saveProfile(profile)
        let lighter = try #require(store.profile?.goals)
        #expect(lighter.dailyCalories < heavier.dailyCalories)
        #expect(lighter.dailyActiveKcal < heavier.dailyActiveKcal)
        #expect(lighter.dailyWaterMl < heavier.dailyWaterMl)

        // A new focus changes them again.
        profile = try #require(store.profile)
        profile.goals.primaryFocus = .buildMuscle
        try await store.saveProfile(profile)
        #expect(try #require(store.profile?.goals).dailyCalories > lighter.dailyCalories)

        // Targets set by hand are left alone.
        profile = try #require(store.profile)
        profile.goals.followsPlan = false
        profile.goals.dailyCalories = 2_000
        profile.weightKg = 60
        try await store.saveProfile(profile)
        #expect(store.profile?.goals.dailyCalories == 2_000)
        #expect(ProfileStore(files: files, defaults: defaults).profile?.goals.dailyCalories == 2_000)
    }

    @Test func goalsSavedBeforePlansExistedStayAsTheyWere() throws {
        let json = #"{"dailySteps": 12000, "dailyCalories": 2100, "primaryFocus": "loseWeight"}"#
        let goals = try JSONDecoder().decode(WellnessGoals.self, from: Data(json.utf8))
        #expect(!goals.followsPlan)
        #expect(goals.dailySteps == 12_000 && goals.dailyCalories == 2_100)
        #expect(goals.dailyProteinG == 60)
        #expect(WellnessGoals().followsPlan)
    }

    @Test func eachFocusPutsItsOwnFiguresFirst() {
        #expect(PlanMetric.kinds(for: .loseWeight) == [.food, .move, .steps, .protein])
        #expect(PlanMetric.kinds(for: .buildMuscle).first == .protein)
        #expect(PlanMetric.kinds(for: .sleepBetter).first == .sleep)
        #expect(PlanMetric.kinds(for: .manageStress).first == .mindful)
        for focus in WellnessGoals.Focus.allCases {
            let kinds = PlanMetric.kinds(for: focus)
            #expect(kinds.count == 4 && Set(kinds).count == 4)
        }
        // Food energy is a ceiling: going over isn't meeting it.
        let over = PlanMetric(kind: .food, label: "", icon: "", value: 2_100, target: 1_800, text: "", isLimit: true)
        #expect(over.isOver && !over.isMet && over.progress == 1)
        let within = PlanMetric(kind: .food, label: "", icon: "", value: 1_500, target: 1_800, text: "", isLimit: true)
        #expect(within.isMet && !within.isOver)
        #expect(!PlanMetric(kind: .food, label: "", icon: "", value: 0, target: 1_800, text: "", isLimit: true).isMet)
        #expect(PlanMetric(kind: .steps, label: "", icon: "", value: 9_000, target: 8_500, text: "").isMet)
    }

    @Test func thePaceIsSaidInWords() {
        let kg: (Double) -> String = { "\($0.formatted(.number.precision(.fractionLength(1)))) kg" }
        #expect(plan(.loseWeight).paceText(formatWeight: kg) == "About 0.4 kg lighter each week at this pace.")
        #expect(plan(.buildMuscle).paceText(formatWeight: kg) == "About 0.2 kg heavier each week at this pace.")
        #expect(plan(.balanced).paceText(formatWeight: kg) == "Eating this much keeps your weight steady.")
        #expect(plan(.loseWeight, weight: 60, target: 62).paceText(formatWeight: kg).contains("reached"))
    }

    @Test func weightsAreKeptAndSynced() {
        let files = SecureFileStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("VitalaWeight-\(UUID().uuidString)", isDirectory: true))
        let defaults = UserDefaults(suiteName: "VitalaWeight-\(UUID().uuidString)")!
        let store = DataStore(files: files, defaults: defaults)
        let first = WeightEntry(date: .now.addingTimeInterval(-86_400 * 7), kg: 72.4)
        store.logWeight(first)
        store.logWeight(WeightEntry(date: .now, kg: 71.8))
        store.flush()
        let relaunched = DataStore(files: files, defaults: defaults)
        #expect(relaunched.weights.map(\.kg) == [72.4, 71.8])
        relaunched.deleteWeight(first)
        #expect(relaunched.weights.count == 1)

        var other = DataStore.Snapshot(summaries: [:], workouts: [], meals: [], water: [], sleep: [],
                                       mindfulness: [], customFoods: nil)
        other.weights = [WeightEntry(date: .now, kg: 80)]
        #expect(SyncMerge.merge(relaunched.snapshot, other).weights?.count == 2)
    }
}
