import Foundation

/// Daily targets worked out from who the user is and what they want: their
/// focus, sex, age, height, weight and how active they are. Pure
/// arithmetic, so every rule is tested, and the same inputs always give the
/// same plan.
///
/// The figures are general estimates for healthy adults, not medical
/// advice. They are deliberately moderate: weight loss is planned at no
/// more than about half a kilo a week, and food energy never goes below a
/// floor.
struct GoalPlan: Equatable {
    let focus: WellnessGoals.Focus
    /// Energy used at complete rest (Mifflin–St Jeor), kcal a day.
    let restingCalories: Int
    /// Energy used in a typical day at this activity level: eating this
    /// much keeps weight steady.
    let maintenanceCalories: Int
    /// Food energy target.
    let calories: Int
    let proteinG: Int
    /// Move: active energy to burn.
    let activeKcal: Int
    let steps: Int
    let exerciseMinutes: Int
    let weeklyWorkouts: Int
    let waterMl: Int
    let sleepHours: Double
    let mindfulMinutes: Int
    /// The weight target has been reached, so food energy holds weight
    /// steady instead of changing it.
    let targetReached: Bool

    /// Weight change the food target points to, in kilograms a week;
    /// negative is a loss. A kilogram of body weight is about 7,700 kcal.
    var weeklyChangeKg: Double {
        Double(calories - maintenanceCalories) * 7 / 7_700
    }

    /// The lowest food-energy target the plan will set.
    static func calorieFloor(for sex: UserProfile.Gender) -> Int {
        switch sex {
        case .male: 1_500
        case .female: 1_200
        case .nonBinary, .unspecified: 1_350
        }
    }

    init(focus: WellnessGoals.Focus, sex: UserProfile.Gender, age: Int, heightCm: Double, weightKg: Double,
         activity: UserProfile.ActivityLevel, targetWeightKg: Double? = nil) {
        self.focus = focus

        // Energy: Mifflin–St Jeor at rest, times the activity level.
        let sexOffset: Double
        switch sex {
        case .male: sexOffset = 5
        case .female: sexOffset = -161
        case .nonBinary, .unspecified: sexOffset = -78
        }
        let resting = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + sexOffset
        let maintenance = resting * activity.multiplier
        restingCalories = Int(resting.rounded())
        maintenanceCalories = Self.round(maintenance, to: 50)

        // A weight target that has been reached turns the plan to holding steady.
        let reached: Bool
        switch (focus, targetWeightKg) {
        case (.loseWeight, let target?): reached = weightKg <= target
        case (.buildMuscle, let target?): reached = weightKg >= target
        default: reached = false
        }
        targetReached = reached

        // Food energy: a moderate deficit to lose, a small surplus to build.
        var food = maintenance
        if !reached {
            switch focus {
            case .loseWeight: food -= min(500, maintenance * 0.2)
            case .buildMuscle: food += 250
            default: break
            }
        }
        calories = min(max(Self.round(food, to: 50), Self.calorieFloor(for: sex)), 4_000)

        // Protein by body weight; when losing, by the weight being aimed for.
        let perKilo: Double
        switch focus {
        case .loseWeight: perKilo = 1.6
        case .buildMuscle: perKilo = 1.8
        default: perKilo = 1.0
        }
        var proteinWeight = weightKg
        if focus == .loseWeight, let target = targetWeightKg, target < weightKg { proteinWeight = max(target, 40) }
        proteinG = min(max(Self.round(proteinWeight * perKilo, to: 5), 40), 220)

        // Move: a heavier body burns more doing the same thing.
        let movePerKilo: Double
        switch focus {
        case .loseWeight: movePerKilo = 7
        case .buildMuscle, .balanced: movePerKilo = 6
        case .sleepBetter, .manageStress: movePerKilo = 5
        }
        activeKcal = min(max(Self.round(weightKg * movePerKilo, to: 10), 200), 900)

        // Steps: a distance to walk, turned into steps by stride length,
        // which follows height. Taller people cover it in fewer steps.
        let kilometres: Double
        switch focus {
        case .loseWeight: kilometres = 7
        case .balanced: kilometres = 6
        case .buildMuscle, .sleepBetter: kilometres = 5.5
        case .manageStress: kilometres = 5
        }
        let strideMetres = max(heightCm, 100) / 100 * 0.414
        var walked = kilometres * 1_000 / strideMetres
        if age >= 65 { walked *= 0.85 }
        steps = min(max(Self.round(walked, to: 500), 4_000), 15_000)

        switch focus {
        case .loseWeight:
            exerciseMinutes = 45
            weeklyWorkouts = 5
        case .buildMuscle:
            exerciseMinutes = 45
            weeklyWorkouts = 4
        case .balanced:
            exerciseMinutes = 30
            weeklyWorkouts = 4
        case .sleepBetter, .manageStress:
            exerciseMinutes = 30
            weeklyWorkouts = 3
        }

        // Water by body weight, with more on plans that train harder.
        let extraWater: Double = focus == .loseWeight || focus == .buildMuscle ? 350 : 0
        waterMl = min(max(Self.round(weightKg * 33 + extraWater, to: 100), 1_500), 4_000)

        // Sleep by age.
        switch age {
        case ..<18: sleepHours = 9
        case 65...: sleepHours = 7.5
        default: sleepHours = 8
        }

        switch focus {
        case .manageStress: mindfulMinutes = 15
        case .sleepBetter, .balanced: mindfulMinutes = 10
        case .loseWeight, .buildMuscle: mindfulMinutes = 5
        }
    }

    /// These targets written into a set of goals, keeping the user's focus
    /// and weight target.
    func applied(to goals: WellnessGoals) -> WellnessGoals {
        var updated = goals
        updated.dailyCalories = calories
        updated.dailyProteinG = proteinG
        updated.dailyActiveKcal = activeKcal
        updated.dailySteps = steps
        updated.dailyExerciseMinutes = exerciseMinutes
        updated.weeklyWorkouts = weeklyWorkouts
        updated.dailyWaterMl = waterMl
        updated.sleepHours = sleepHours
        updated.dailyMindfulMinutes = mindfulMinutes
        return updated
    }

    /// One line on what the food target means: "About 0.4 kg a week".
    func paceText(formatWeight: (Double) -> String) -> String {
        if targetReached { return "You've reached your target weight, so this holds it steady." }
        let weekly = abs(weeklyChangeKg)
        guard weekly >= 0.05 else { return "Eating this much keeps your weight steady." }
        let amount = formatWeight(weekly)
        return weeklyChangeKg < 0
            ? "About \(amount) lighter each week at this pace."
            : "About \(amount) heavier each week at this pace."
    }

    private static func round(_ value: Double, to step: Int) -> Int {
        Int((value / Double(step)).rounded()) * step
    }
}

extension UserProfile {
    /// The plan for this profile, or nil until height, weight and birthday
    /// are known, or for anyone under 13.
    func plan(on date: Date = .now) -> GoalPlan? {
        guard let kg = weightKg, let cm = heightCm, let age = age(on: date), age >= 13,
              Self.weightRangeKg.contains(kg), Self.heightRangeCm.contains(cm) else { return nil }
        return GoalPlan(focus: goals.primaryFocus, sex: gender, age: age, heightCm: cm, weightKg: kg,
                        activity: activityLevel, targetWeightKg: goals.weightTargetKg)
    }

    /// This profile with its targets brought up to date with the plan, when
    /// the user has left the targets to Vitala.
    func followingPlan(on date: Date = .now) -> UserProfile {
        guard goals.followsPlan, let plan = plan(on: date) else { return self }
        var updated = self
        updated.goals = plan.applied(to: goals)
        return updated
    }
}

/// A weight the user recorded, kept so progress towards a target can be seen.
struct WeightEntry: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var date: Date
    var kg: Double
}
