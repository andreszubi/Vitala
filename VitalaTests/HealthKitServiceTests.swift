import Foundation
import Testing
@testable import Vitala

struct HealthKitServiceTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func mergesOverlappingSleepFromTwoSources() {
        // Phone: 23:00–07:00, Watch: 23:30–06:30 — should count 8 h, not 15.
        let phone = DateInterval(start: t0, duration: 8 * 3600)
        let watch = DateInterval(start: t0.addingTimeInterval(1800), duration: 7 * 3600)
        #expect(HealthKitService.mergedDuration([phone, watch]) == 8 * 3600)
    }

    @Test func keepsGapsBetweenIntervals() {
        let a = DateInterval(start: t0, duration: 600)
        let b = DateInterval(start: t0.addingTimeInterval(3600), duration: 600)
        #expect(HealthKitService.mergedDuration([b, a]) == 1200)
    }

    @Test func syncIdentifiersAreStablePerEntry() {
        #expect(HealthKitService.syncID("water", "abc") == HealthKitService.syncID("water", "abc"))
        #expect(HealthKitService.syncID("water", "abc") != HealthKitService.syncID("sleep", "abc"))
    }

    // MARK: Imported history

    private func period(_ startHour: Double, _ hours: Double, asleep: Bool = true) -> HealthKitService.SleepPeriod {
        .init(interval: DateInterval(start: t0.addingTimeInterval(startHour * 3600), duration: hours * 3600),
              asleep: asleep)
    }

    @Test func groupsWatchStagesIntoOneNight() {
        // Asleep 23–2, awake gap, asleep 2:30–7; a nap the next afternoon.
        let nights = HealthKitService.nights(from: [period(0, 3), period(3.5, 4.5), period(15, 1)])
        #expect(nights.count == 2)
        #expect(nights[0].hours == 7.5)
        #expect(nights[0].wakeTime == t0.addingTimeInterval(8 * 3600))
        #expect(nights.allSatisfy { $0.isFromHealth })
    }

    @Test func prefersAsleepStagesOverTimeInBed() {
        let nights = HealthKitService.nights(from: [period(0, 9, asleep: false), period(0.5, 8)])
        #expect(nights.count == 1)
        #expect(nights[0].hours == 8)
        #expect(nights[0].quality == .great)
    }

    @Test func usesTimeInBedWhenThatIsAllThereIs() {
        let nights = HealthKitService.nights(from: [period(0, 6.5, asleep: false)])
        #expect(nights.first?.hours == 6.5)
        #expect(nights.first?.quality == .fair)
    }

    @Test func loggedNightWinsOverOverlappingHealthNight() {
        let logged = SleepEntry(bedTime: t0, wakeTime: t0.addingTimeInterval(8 * 3600), quality: .good)
        let imported = HealthKitService.nights(from: [period(0.5, 7), period(30, 7)])
        let merged = DataStore.merge([logged], with: imported)
        #expect(merged.count == 2)
        #expect(merged.filter { $0.isFromHealth }.count == 1)
    }

    @Test func filesHealthFoodIntoMealsByTimeOfDay() {
        let cal = Calendar.current
        let day = cal.startOfDay(for: t0)
        func at(_ hour: Int, _ kcal: Double) -> HealthKitService.HealthFood {
            .init(date: cal.date(byAdding: .hour, value: hour, to: day)!, source: "Tracker", kcal: kcal, protein: 10)
        }
        let meals = HealthKitService.meals(from: [at(8, 300), at(9, 150), at(13, 600)])
        #expect(meals.count == 2)
        let breakfast = meals.first { $0.type == .breakfast }
        #expect(breakfast?.totalCalories == 450)
        #expect(breakfast?.totalProtein == 20)
        #expect(breakfast?.isFromHealth == true)
    }
}
