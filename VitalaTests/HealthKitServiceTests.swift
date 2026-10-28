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
}
