import Testing
@testable import Vitala

@MainActor
struct UnitsServiceTests {
    @Test func metricRoundTripsWeight() {
        let units = UnitsService()
        units.system = .metric
        #expect(units.parseWeightToKg("70") == 70)
        #expect(units.formatWeight(kg: 70) == "70 kg")
    }

    @Test func imperialConvertsWeight() throws {
        let units = UnitsService()
        units.system = .imperial
        let kg = try #require(units.parseWeightToKg("154"))
        #expect(abs(kg - 69.85) < 0.01)
        units.system = .metric
    }

    @Test func imperialHeightUsesFeetAndInches() throws {
        let units = UnitsService()
        units.system = .imperial
        let cm = try #require(units.parseHeightToCm(metric: "", feet: "5", inches: "8"))
        #expect(abs(cm - 172.72) < 0.01)
        let split = units.cmToFeetInches(cm)
        #expect(split.feet == 5)
        #expect(split.inches == 8)
        units.system = .metric
    }
}
