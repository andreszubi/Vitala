import Foundation
import HealthKit
import OSLog

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private let log = Logger(subsystem: "com.vitala.healthyliving", category: "health")

    /// True once the user has answered the Apple Health permission sheet.
    /// HealthKit never reveals whether *read* access was granted, so this is
    /// "connected", not "every type allowed".
    @Published private(set) var isAuthorized: Bool = false
    @Published var todaySummary: DailySummary = DailySummary(date: .now)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {
        Task { await refreshAuthorizationState() }
    }

    // MARK: Types

    /// Only the types Vitala displays. Requesting more than you use is an App
    /// Review rejection for HealthKit apps.
    private var readTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = []
        if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .heartRate) { set.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .mindfulSession) { set.insert(t) }
        return set
    }

    private var writeTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let t = HKObjectType.quantityType(forIdentifier: .dietaryWater) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { set.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .mindfulSession) { set.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(t) }
        return set
    }

    // MARK: Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            await refreshAuthorizationState()
            await refreshToday()
        } catch {
            log.error("HealthKit authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Re-derives the connection state from HealthKit itself, so it survives
    /// relaunches without storing a flag of our own.
    func refreshAuthorizationState() async {
        guard isAvailable else { isAuthorized = false; return }
        let status = try? await store.statusForAuthorizationRequest(toShare: writeTypes, read: readTypes)
        isAuthorized = status == .unnecessary
    }

    private func canWrite(_ type: HKObjectType) -> Bool {
        isAvailable && store.authorizationStatus(for: type) == .sharingAuthorized
    }

    // MARK: Reads

    func refreshToday() async {
        guard isAvailable else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        async let steps = quantitySum(.stepCount, unit: .count(), predicate: predicate)
        async let kcal  = quantitySum(.activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)
        async let dist  = quantitySum(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), predicate: predicate)
        async let exMin = quantitySum(.appleExerciseTime, unit: .minute(), predicate: predicate)
        async let hr    = mostRecentHeartRate()
        // Last night: anything that ended after 6 pm yesterday.
        async let sleep = mergedHours(.sleepAnalysis, from: start.addingTimeInterval(-6 * 3600), to: .now,
                                      where: { HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue).contains($0) })
        async let mindful = mergedHours(.mindfulSession, from: start, to: end, where: { _ in true })

        var summary = DailySummary(date: start)
        summary.steps = Int((try? await steps) ?? 0)
        summary.activeKcal = Int((try? await kcal) ?? 0)
        summary.distanceKm = (try? await dist) ?? 0
        summary.exerciseMinutes = Int((try? await exMin) ?? 0)
        summary.heartRate = (try? await hr).flatMap { Int($0) }
        summary.sleepHours = (try? await sleep) ?? 0
        summary.mindfulMinutes = Int((((try? await mindful) ?? 0) * 60).rounded())
        self.todaySummary = summary
    }

    /// Daily step totals for the given range, keyed by start of day.
    func dailySteps(from start: Date, to end: Date) async -> [Date: Int] {
        guard isAvailable, let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [:] }
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: start)
        let predicate = HKQuery.predicateForSamples(withStart: anchor, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate,
                                                options: .cumulativeSum, anchorDate: anchor,
                                                intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, results, _ in
                var out: [Date: Int] = [:]
                results?.enumerateStatistics(from: anchor, to: end) { stats, _ in
                    if let sum = stats.sumQuantity() {
                        out[stats.startDate] = Int(sum.doubleValue(for: .count()))
                    }
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
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

    /// Total hours covered by category samples in a window, merging overlaps
    /// so a phone and a watch recording the same night aren't double-counted.
    private func mergedHours(_ id: HKCategoryTypeIdentifier, from start: Date, to end: Date,
                             where include: @escaping (Int) -> Bool) async throws -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: id) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let intervals: [DateInterval] = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                let list = (samples as? [HKCategorySample] ?? [])
                    .filter { include($0.value) }
                    .map { DateInterval(start: max($0.startDate, start), end: min($0.endDate, end)) }
                cont.resume(returning: list)
            }
            store.execute(q)
        }
        return Self.mergedDuration(intervals) / 3600
    }

    nonisolated static func mergedDuration(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var current: DateInterval?
        for interval in sorted {
            if let c = current, interval.start <= c.end {
                current = DateInterval(start: c.start, end: max(c.end, interval.end))
            } else {
                if let c = current { total += c.duration }
                current = interval
            }
        }
        if let c = current { total += c.duration }
        return total
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
    //
    // Every sample Vitala writes carries a sync identifier derived from the
    // local entry's id. Saving again replaces the old sample, and deleting a
    // log removes it from Apple Health too, so edits never leave duplicates.

    func save(water entry: WaterEntry) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater), canWrite(type) else { return }
        let id = Self.syncID("water", entry.id)
        let qty = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(entry.amountMl))
        await replace(id, types: [type]) {
            [HKQuantitySample(type: type, quantity: qty, start: entry.loggedAt, end: entry.loggedAt,
                              metadata: Self.metadata(id))]
        }
    }

    func delete(water entry: WaterEntry) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater), canWrite(type) else { return }
        await deleteSamples(Self.syncID("water", entry.id), types: [type])
    }

    func save(mindfulness entry: LoggedMindfulness) async {
        guard let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession), canWrite(type) else { return }
        let id = Self.syncID("mindful", entry.id)
        let start = entry.completedAt.addingTimeInterval(-Double(entry.minutes) * 60)
        await replace(id, types: [type]) {
            [HKCategorySample(type: type, value: HKCategoryValue.notApplicable.rawValue,
                              start: start, end: entry.completedAt, metadata: Self.metadata(id))]
        }
    }

    func delete(mindfulness entry: LoggedMindfulness) async {
        guard let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession), canWrite(type) else { return }
        await deleteSamples(Self.syncID("mindful", entry.id), types: [type])
    }

    func save(sleep entry: SleepEntry) async {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis), canWrite(type),
              entry.wakeTime > entry.bedTime else { return }
        let id = Self.syncID("sleep", entry.id)
        await replace(id, types: [type]) {
            [HKCategorySample(type: type, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                              start: entry.bedTime, end: entry.wakeTime, metadata: Self.metadata(id))]
        }
    }

    func delete(sleep entry: SleepEntry) async {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis), canWrite(type) else { return }
        await deleteSamples(Self.syncID("sleep", entry.id), types: [type])
    }

    func save(workout session: WorkoutSession) async {
        let workoutType = HKObjectType.workoutType()
        guard canWrite(workoutType), let end = session.endedAt, end > session.startedAt else { return }
        let id = Self.syncID("workout", session.id)
        let related = workoutRelatedTypes
        await deleteSamples(id, types: [workoutType] + related)

        let cfg = HKWorkoutConfiguration()
        cfg.activityType = (session.category ?? .cardio).healthKitType
        let builder = HKWorkoutBuilder(healthStore: store, configuration: cfg, device: .local())
        do {
            try await builder.beginCollection(at: session.startedAt)
            var samples: [HKSample] = []
            if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
               canWrite(energy), session.caloriesBurned > 0 {
                samples.append(HKQuantitySample(type: energy,
                                                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(session.caloriesBurned)),
                                                start: session.startedAt, end: end, metadata: Self.metadata(id)))
            }
            if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
               canWrite(distance), let km = session.distanceKm, km > 0 {
                samples.append(HKQuantitySample(type: distance,
                                                quantity: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: km),
                                                start: session.startedAt, end: end, metadata: Self.metadata(id)))
            }
            if !samples.isEmpty { try await builder.addSamples(samples) }
            try await builder.addMetadata(Self.metadata(id))
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            log.error("Couldn't save workout: \(error.localizedDescription, privacy: .public)")
        }
    }

    func delete(workout session: WorkoutSession) async {
        guard canWrite(HKObjectType.workoutType()) else { return }
        await deleteSamples(Self.syncID("workout", session.id),
                            types: [HKObjectType.workoutType()] + workoutRelatedTypes)
    }

    private var workoutRelatedTypes: [HKSampleType] {
        [HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
         HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)]
            .compactMap { $0 }
            .filter { canWrite($0) }
    }

    private func replace(_ syncID: String, types: [HKSampleType], make: () -> [HKObject]) async {
        await deleteSamples(syncID, types: types)
        do {
            try await store.save(make())
        } catch {
            log.error("Couldn't save to Health: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteSamples(_ syncID: String, types: [HKSampleType]) async {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier,
                                                    allowedValues: [syncID])
        for type in types {
            _ = try? await store.deleteObjects(of: type, predicate: predicate)
        }
    }

    nonisolated static func syncID(_ kind: String, _ id: String) -> String {
        "com.vitala.\(kind).\(id)"
    }

    private static func metadata(_ syncID: String) -> [String: Any] {
        [HKMetadataKeySyncIdentifier: syncID,
         HKMetadataKeySyncVersion: Int(Date().timeIntervalSince1970 * 1000)]
    }
}

extension Workout.Category {
    var healthKitType: HKWorkoutActivityType {
        switch self {
        case .yoga: .yoga
        case .strength: .functionalStrengthTraining
        case .cardio: .mixedCardio
        case .hiit: .highIntensityIntervalTraining
        case .pilates: .pilates
        case .mobility: .flexibility
        case .walking: .walking
        case .running: .running
        }
    }
}
