import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    @Published var isAuthorized: Bool = false
    @Published var todaySummary: DailySummary = DailySummary(date: .now)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: Types

    private var readTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = []
        if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .heartRate) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .bodyMass) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .height) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { set.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .mindfulSession) { set.insert(t) }
        return set
    }

    private var writeTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = []
        if let t = HKObjectType.quantityType(forIdentifier: .dietaryWater) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .mindfulSession) { set.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(t) }
        if let t = HKObjectType.workoutType() as HKSampleType? { set.insert(t) }
        return set
    }

    // MARK: Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            await refreshToday()
        } catch {
            print("HealthKit auth error: \(error)")
        }
    }

    // MARK: Reads

    func refreshToday() async {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        async let steps = quantitySum(.stepCount, unit: .count(), predicate: predicate)
        async let kcal  = quantitySum(.activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)
        async let dist  = quantitySum(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), predicate: predicate)
        async let exMin = quantitySum(.appleExerciseTime, unit: .minute(), predicate: predicate)
        async let hr    = mostRecentHeartRate()

        var summary = DailySummary(date: start)
        summary.steps = Int((try? await steps) ?? 0)
        summary.activeKcal = Int((try? await kcal) ?? 0)
        summary.distanceKm = (try? await dist) ?? 0
        summary.exerciseMinutes = Int((try? await exMin) ?? 0)
        summary.heartRate = (try? await hr).flatMap { Int($0) }
        self.todaySummary = summary
    }

    private func quantitySum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    private func mostRecentHeartRate() async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                let bpm = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                cont.resume(returning: bpm)
            }
            store.execute(q)
        }
    }

    // MARK: Writes

    /// True only when the entitlement is present AND the user explicitly granted access.
    /// Without this guard, write calls (especially HKWorkoutBuilder) can hang
    /// indefinitely on the simulator.
    private var canWrite: Bool {
        isAvailable && isAuthorized
    }

    func logWater(ml: Double, at date: Date = .now) async throws {
        guard canWrite,
              let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let q = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: ml)
        let sample = HKQuantitySample(type: type, quantity: q, start: date, end: date)
        try await store.save(sample)
    }

    func logMindfulness(start: Date, end: Date) async throws {
        guard canWrite,
              let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        let sample = HKCategorySample(type: type, value: 0, start: start, end: end)
        try await store.save(sample)
    }

    func logWorkout(activity: HKWorkoutActivityType, start: Date, end: Date, kcal: Double) async throws {
        guard canWrite else { return }
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = activity
        let builder = HKWorkoutBuilder(healthStore: store, configuration: cfg, device: .local())
        try await builder.beginCollection(at: start)
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            let qty = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
            try await builder.addSamples([HKQuantitySample(type: energyType, quantity: qty, start: start, end: end)])
        }
        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
    }
}
