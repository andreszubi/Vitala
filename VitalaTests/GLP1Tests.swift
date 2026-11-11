import Foundation
import Testing
@testable import Vitala

@MainActor
struct GLP1Tests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func at(_ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func dose(_ medication: String, _ amount: Double, on day: Int, hour: Int = 9,
                      site: GLP1Dose.Site? = nil) -> GLP1Dose {
        let known = GLP1Medication.find(medication)!
        return GLP1Dose(takenAt: at(day, hour), medicationID: known.id, medicationName: known.brand,
                        amount: amount, unit: known.unit, site: site)
    }

    @Test func theMedicineListIsWellFormed() {
        let all = GLP1Medication.all
        #expect(Set(all.map(\.id)).count == all.count)
        for medicine in all {
            #expect(!medicine.strengths.isEmpty, "\(medicine.brand) has no strengths")
            #expect(medicine.strengths == medicine.strengths.sorted(), "\(medicine.brand) strengths are in order")
            #expect(medicine.strengths.allSatisfy { $0 > 0 })
            #expect(["mg", "mcg"].contains(medicine.unit))
            #expect(GLP1Medication.find(medicine.id) == medicine)
        }
        #expect(GLP1Medication.find("other")?.strengths.isEmpty == true)
        #expect(GLP1Medication.find("nonsense") == nil)
        // Tablets aren't injected.
        #expect(GLP1Medication.find("rybelsus")?.form == .tablet)
    }

    @Test func amountsReadWithoutTrailingZeros() {
        #expect(GLP1Dose.text(0.5, unit: "mg") == "0.5 mg")
        #expect(GLP1Dose.text(1, unit: "mg") == "1 mg")
        #expect(GLP1Dose.text(12.5, unit: "mg") == "12.5 mg")
        #expect(GLP1Dose.text(0.25, unit: "mg") == "0.25 mg")
        #expect(GLP1Dose.text(10, unit: "mcg") == "10 mcg")
    }

    @Test func aWeeklyDoseIsDueByTheDayNotTheHour() {
        let doses = [dose("wegovy", 0.25, on: 2), dose("wegovy", 0.5, on: 9, hour: 20)]
        #expect(GLP1Schedule.latest(doses)?.amount == 0.5)
        #expect(GLP1Schedule.nextDue(after: doses) == at(16, 20))
        #expect(GLP1Schedule.due(after: doses, now: at(10, 8), calendar: calendar) == .upcoming(days: 6))
        #expect(GLP1Schedule.due(after: doses, now: at(15, 23), calendar: calendar) == .upcoming(days: 1))
        // Taken at 8 pm last week: due all of today, from the morning.
        #expect(GLP1Schedule.due(after: doses, now: at(16, 7), calendar: calendar) == .today)
        #expect(GLP1Schedule.due(after: doses, now: at(16, 23), calendar: calendar) == .today)
        #expect(GLP1Schedule.due(after: doses, now: at(17, 1), calendar: calendar) == .overdue(days: 1))
        #expect(GLP1Schedule.due(after: doses, now: at(20, 9), calendar: calendar) == .overdue(days: 4))
        #expect(GLP1Schedule.due(after: [], now: at(20), calendar: calendar) == nil)
    }

    @Test func aDailyDoseIsDueTheNextDay() {
        let doses = [dose("saxenda", 1.2, on: 9, hour: 8)]
        #expect(GLP1Schedule.due(after: doses, now: at(9, 12), calendar: calendar) == .upcoming(days: 0))
        #expect(GLP1Schedule.due(after: doses, now: at(10, 9), calendar: calendar) == .today)
        #expect(GLP1Schedule.due(after: doses, now: at(12, 9), calendar: calendar) == .overdue(days: 2))
    }

    @Test func dueTextsReadNaturally() {
        #expect(GLP1Schedule.Due.today.text == "Next dose due today")
        #expect(GLP1Schedule.Due.upcoming(days: 0).text == "Next dose due later today")
        #expect(GLP1Schedule.Due.upcoming(days: 1).text == "Next dose due tomorrow")
        #expect(GLP1Schedule.Due.upcoming(days: 5).text == "Next dose due in 5 days")
        #expect(GLP1Schedule.Due.overdue(days: 1).text == "Next dose was due yesterday")
        #expect(GLP1Schedule.Due.overdue(days: 3).text == "Next dose was due 3 days ago")
    }

    @Test func sideEffectsSummariseInListOrder() {
        let entry = SideEffectEntry(date: at(9), symptoms: [.fatigue, .nausea], severity: .moderate)
        #expect(entry.summary == "Nausea, Tiredness")
        #expect(SideEffectEntry(date: at(9), symptoms: [], severity: .mild).summary == "No symptoms chosen")
    }

    @Test func dosesAndSideEffectsAreSavedEditedDeletedAndExported() throws {
        let files = SecureFileStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("VitalaGLP1-\(UUID().uuidString)", isDirectory: true))
        let defaults = UserDefaults(suiteName: "VitalaGLP1-\(UUID().uuidString)")!
        let store = DataStore(files: files, defaults: defaults)
        var first = dose("zepbound", 2.5, on: 2, site: .abdomen)
        store.saveGLP1Dose(first)
        store.saveGLP1Dose(dose("zepbound", 5, on: 9, site: .thigh))
        first.notes = "First pen"
        store.saveGLP1Dose(first)
        let effect = SideEffectEntry(date: at(3), symptoms: [.nausea], severity: .mild, notes: "Eased by evening")
        store.saveSideEffect(effect)
        store.saveSideEffect(SideEffectEntry(date: at(4), symptoms: [.headache], severity: .mild))
        store.deleteSideEffect(store.sideEffects[1])
        #expect(store.glp1Doses.count == 2)

        let json = try #require(String(data: try DataExport(profile: nil, store: store).jsonData(), encoding: .utf8))
        #expect(json.contains("\"glp1Doses\"") && json.contains("Zepbound") && json.contains("Eased by evening"))

        store.flush()
        let relaunched = DataStore(files: files, defaults: defaults)
        #expect(relaunched.glp1Doses.first { $0.id == first.id }?.notes == "First pen")
        #expect(relaunched.glp1Doses.first { $0.id == first.id }?.site == .abdomen)
        #expect(relaunched.sideEffects.map(\.summary) == ["Nausea"])

        relaunched.deleteGLP1Dose(first)
        relaunched.eraseAll()
        #expect(relaunched.glp1Doses.isEmpty && relaunched.sideEffects.isEmpty)
    }

    @Test func dosesAndSideEffectsSyncBetweenDevices() {
        var phone = DataStore.Snapshot(summaries: [:], workouts: [], meals: [], water: [], sleep: [],
                                       mindfulness: [], customFoods: nil)
        var other = phone
        let taken = dose("ozempic", 0.5, on: 9)
        let felt = SideEffectEntry(date: at(10), symptoms: [.nausea, .lowAppetite], severity: .moderate)
        phone.glp1Doses = [taken]
        other.sideEffects = [felt]
        let merged = SyncMerge.merge(phone, other)
        #expect(merged.glp1Doses == [taken])
        #expect(merged.sideEffects == [felt])
        #expect(!SyncMerge.sameContent(phone, merged), "a copy missing the side effect is not the same")
        #expect(SyncMerge.sameContent(merged, SyncMerge.merge(other, phone)))
    }
}
