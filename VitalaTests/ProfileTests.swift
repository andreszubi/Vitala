import Foundation
import Testing
@testable import Vitala

struct ProfileTests {
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 28))!

    private func profile(gender: UserProfile.Gender, focus: WellnessGoals.Focus = .balanced) -> UserProfile {
        var p = UserProfile(id: "1", displayName: "Test")
        p.dateOfBirth = Calendar.current.date(from: DateComponents(year: 1995, month: 1, day: 1))
        p.gender = gender
        p.heightCm = 170
        p.weightKg = 65
        p.activityLevel = .moderate
        p.goals.primaryFocus = focus
        return p
    }

    @Test func suggestsCaloriesFromMifflinStJeor() {
        // Female, 31 y, 170 cm, 65 kg: 10*65 + 6.25*170 - 5*31 - 161 = 1396.5; × 1.55 ≈ 2165 → 2150.
        #expect(profile(gender: .female).suggestedDailyCalories(on: now) == 2150)
    }

    @Test func focusAdjustsSuggestion() {
        let base = profile(gender: .male).suggestedDailyCalories(on: now)!
        #expect(profile(gender: .male, focus: .loseWeight).suggestedDailyCalories(on: now)! < base)
        #expect(profile(gender: .male, focus: .buildMuscle).suggestedDailyCalories(on: now)! > base)
    }

    @Test func noSuggestionWithoutMeasurements() {
        var p = profile(gender: .female)
        p.weightKg = nil
        #expect(p.suggestedDailyCalories(on: now) == nil)
    }
}
