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

@MainActor
struct DistanceParsingTests {
    @Test func parsesCommaDecimalsAndRejectsEmpty() throws {
        let units = UnitsService()
        units.system = .metric
        #expect(units.parseDistanceToKm("5,5") == 5.5)
        #expect(units.parseDistanceToKm("") == nil)
        #expect(units.parseDistanceToKm("0") == nil)
    }

    @Test func imperialMilesConvertToKm() throws {
        let units = UnitsService()
        units.system = .imperial
        let km = try #require(units.parseDistanceToKm("3.1"))
        #expect(abs(km - 4.989) < 0.01)
        units.system = .metric
    }
}

@MainActor
struct HeightRoundingTests {
    @Test func heightsJustUnderAWholeFootKeepTheirFoot() {
        let units = UnitsService()
        units.system = .imperial
        // 182 cm is 71.65 in: six feet, not "5' 0"".
        #expect(units.cmToFeetInches(182) == (6, 0))
        #expect(units.formatHeight(cm: 182) == "6' 0\"")
        #expect(units.cmToFeetInches(152) == (5, 0))
        #expect(units.cmToFeetInches(172.72) == (5, 8))
        units.system = .metric
    }

    @Test func feetAndInchesSurviveARoundTrip() throws {
        let units = UnitsService()
        units.system = .imperial
        // What Edit profile does on every save: show, then read back.
        for cm in stride(from: 120.0, through: 220.0, by: 1) {
            let shown = units.cmToFeetInches(cm)
            #expect((0..<12).contains(shown.inches))
            let back = try #require(units.parseHeightToCm(metric: "", feet: "\(shown.feet)", inches: "\(shown.inches)"))
            #expect(abs(back - cm) <= 1.27 + 0.001, "\(cm) cm came back as \(back)")
        }
        units.system = .metric
    }
}
