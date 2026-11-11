import CloudKit
import Foundation
import OSLog
import UIKit

/// The user's data as it is kept in iCloud: a format version and the bytes.
struct CloudState: Equatable {
    var version: Int
    var payload: Data
}

enum CloudAvailability: Equatable {
    case available
    /// Not signed in to iCloud on this device.
    case noAccount
    /// iCloud is switched off for this device by a restriction.
    case restricted
    /// Signed in, but iCloud can't vouch for the account right now: the
    /// device usually needs the user to sign in again or review the
    /// account in Settings.
    case needsAttention
    /// iCloud can't say right now; try again later.
    case unknown
}

/// Where the synced copy lives. The app talks to CloudKit; tests use a
/// stand-in that behaves the same way.
protocol CloudStateStore: Sendable {
    func availability() async -> CloudAvailability
    /// The copy in iCloud, or nil if nothing has been saved there.
    func fetch() async throws -> CloudState?
    /// Replaces the copy last fetched. Returns false, and changes nothing,
    /// if another device saved since then: fetch, merge and try again.
    func save(_ state: CloudState) async throws -> Bool
    /// Removes the copy from iCloud.
    func delete() async throws
}

/// Keeps logs, the journal, favourite foods, saved meals and built workouts
/// the same on every device signed in to the same iCloud account. Off until
/// the user turns it on.
///
/// One copy of the data lives in the user's private iCloud database. To
/// sync, a device fetches it, merges it with its own (see `SyncMerge`),
/// takes in what was new, and saves the result back if it added anything.
/// If another device saved in between, it starts again from that copy.
@MainActor
final class CloudSync: ObservableObject {
    enum Status: Equatable {
        case off
        /// On, but nothing has synced yet since the app opened.
        case waiting
        case syncing
        case upToDate(Date)
        case noAccount
        case restricted
        /// Signed in, but the account needs the user's attention in Settings
        /// before iCloud will accept requests from this device.
        case accountNeedsAttention
        /// A newer version of the app saved the iCloud copy in a format
        /// this one doesn't know. Nothing is changed until the app updates.
        case needsUpdate
        case failed(String)
    }

    static let shared: CloudSync = {
        let sync = CloudSync(store: .shared, cloud: usesCloudKit ? CloudKitStateStore() : NoCloud())
        sync.start()
        return sync
    }()

    /// CloudKit stops the whole app if it is opened by a build without the
    /// iCloud entitlement. Test runs are built unsigned, so they must never
    /// open it: under unit tests, and when a UI test or screenshot run
    /// resets or seeds the data, sync has nowhere to go.
    private static var usesCloudKit: Bool {
        let process = ProcessInfo.processInfo
        if process.environment["XCTestConfigurationFilePath"] != nil { return false }
        #if DEBUG
        if process.arguments.contains("-resetData") || process.arguments.contains("-seedSampleData") { return false }
        #endif
        return true
    }

    /// The newest payload format this version reads and writes. It goes up
    /// whenever a kind of entry is added: a version that doesn't know the
    /// new kind would save the copy back without it.
    /// 2: GLP-1 doses, side effects and weights.
    nonisolated static let formatVersion = 2
    nonisolated static let enabledKey = "vitala.iCloudSync"
    nonisolated static let lastSyncedKey = "vitala.iCloudSync.last"

    @Published private(set) var isOn: Bool
    @Published private(set) var status: Status
    /// The technical description of the last failure, for a support request.
    @Published private(set) var lastErrorDetail: String?

    private let store: DataStore
    private let cloud: CloudStateStore
    private let defaults: UserDefaults
    /// How long to wait after a change before syncing, so a burst of
    /// logging becomes one upload.
    private let quietTime: Duration
    private var isSyncing = false
    private var wantsAnotherPass = false
    private var scheduled: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    /// How many syncs in a row have failed; sets how long to wait before
    /// trying again.
    private var failures = 0
    /// Waits between automatic retries after a failure, then every ten minutes.
    private let retryDelays: [Duration]

    private static let log = Logger(subsystem: "com.vitala.healthyliving", category: "sync")

    init(store: DataStore, cloud: CloudStateStore, defaults: UserDefaults = .standard,
         quietTime: Duration = .seconds(4),
         retryDelays: [Duration] = [.seconds(30), .seconds(120), .seconds(600)]) {
        self.store = store
        self.cloud = cloud
        self.defaults = defaults
        self.quietTime = quietTime
        self.retryDelays = retryDelays
        let on = defaults.bool(forKey: Self.enabledKey)
        isOn = on
        status = on ? .waiting : .off
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    var lastSynced: Date? {
        defaults.object(forKey: Self.lastSyncedKey) as? Date
    }

    /// Starts following the store and the app coming to the front. Called
    /// once for the shared instance.
    func start() {
        store.onLocalChange = { [weak self] in self?.syncSoon() }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncIfStale() }
        })
        // Signing in, signing out, or iCloud becoming ready again.
        observers.append(center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncSoon() }
        })
        if isOn { syncSoon() }
    }

    func setOn(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        defaults.set(on, forKey: Self.enabledKey)
        scheduled?.cancel()
        failures = 0
        if on {
            status = .waiting
            Task { await syncNow() }
        } else {
            status = .off
        }
    }

    /// Syncs a little after the latest change.
    func syncSoon() {
        sync(after: quietTime)
    }

    private func sync(after delay: Duration) {
        guard isOn else { return }
        scheduled?.cancel()
        scheduled = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self.syncNow()
        }
    }

    /// After a failure, tries again by itself: soon at first, then less
    /// often, so "Vitala will try again" is true without the user doing
    /// anything.
    private func retryLater() {
        guard isOn, !retryDelays.isEmpty else { return }
        let step = max(1, min(failures, retryDelays.count))
        sync(after: retryDelays[step - 1])
    }

    /// Syncs on returning to the app, unless it only just did.
    private func syncIfStale() {
        guard isOn else { return }
        if let last = lastSynced, Date.now.timeIntervalSince(last) < 30, case .upToDate = status { return }
        Task { await syncNow() }
    }

    func syncNow() async {
        guard isOn else { return }
        guard !isSyncing else {
            wantsAnotherPass = true
            return
        }
        isSyncing = true
        status = .syncing
        lastErrorDetail = nil
        await runSync()
        isSyncing = false
        switch status {
        case .upToDate:
            failures = 0
            if wantsAnotherPass {
                wantsAnotherPass = false
                if isOn { await syncNow() }
            }
        case .failed, .accountNeedsAttention:
            // Both can clear by themselves; a missing or restricted
            // account, or an app that needs updating, can't.
            wantsAnotherPass = false
            failures += 1
            retryLater()
        default:
            wantsAnotherPass = false
        }
    }

    private func runSync() async {
        switch await cloud.availability() {
        case .available: break
        case .noAccount: status = .noAccount; return
        case .restricted: status = .restricted; return
        case .needsAttention: status = .accountNeedsAttention; return
        case .unknown: status = .failed("iCloud isn't available right now. Vitala will try again."); return
        }
        do {
            // Another device may save between our fetch and our save; when
            // that happens, start again from what it saved.
            for _ in 0..<4 {
                let inCloud = try await cloud.fetch()
                guard isOn else { status = .off; return }
                var remote: DataStore.Snapshot?
                if let inCloud {
                    guard inCloud.version <= Self.formatVersion else {
                        status = .needsUpdate
                        return
                    }
                    remote = Self.decode(inCloud.payload)
                }
                let local = SyncMerge.payload(from: store.snapshot)
                let merged = remote.map { SyncMerge.merge(local, $0) } ?? local
                if !SyncMerge.sameContent(merged, local) { store.adopt(merged) }
                if let remote, SyncMerge.sameContent(merged, remote) {
                    Self.log.notice("Synced: iCloud already had everything")
                    finished()
                    return
                }
                let state = CloudState(version: Self.formatVersion,
                                       payload: try Self.encode(SyncMerge.payload(from: merged)))
                if try await cloud.save(state) {
                    Self.log.notice("Synced: saved to iCloud")
                    finished()
                    return
                }
            }
            status = .failed("iCloud is busy. Vitala will try again shortly.")
        } catch {
            let detail = Self.detail(of: error)
            Self.log.error("Sync failed: \(detail, privacy: .public)")
            lastErrorDetail = detail
            status = .failed(Self.message(for: error))
        }
    }

    /// Everything the error says about itself: its domain and code, what
    /// the server answered, and any error underneath it.
    nonisolated static func detail(of error: Error) -> String {
        let nsError = error as NSError
        var parts = ["\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"]
        if let server = nsError.userInfo["ServerErrorDescription"] as? String { parts.append("server: \(server)") }
        if let partial = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            for (item, itemError) in partial { parts.append("\(item): \(detail(of: itemError))") }
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            parts.append("underlying: \(detail(of: underlying))")
        }
        for (key, value) in nsError.userInfo where "\(key)".contains("RequestUUID") || "\(key)".contains("ContainerID") {
            parts.append("\(key): \(value)")
        }
        return parts.joined(separator: " | ")
    }

    private func finished() {
        let now = Date.now
        defaults.set(now, forKey: Self.lastSyncedKey)
        status = isOn ? .upToDate(now) : .off
    }

    /// Removes the copy in iCloud and turns sync off on this device, so it
    /// isn't saved straight back. What is on this device stays.
    func deleteCloudCopy() async throws {
        setOn(false)
        try await cloud.delete()
        defaults.removeObject(forKey: Self.lastSyncedKey)
    }

    // MARK: Payload

    nonisolated static func encode(_ snapshot: DataStore.Snapshot) throws -> Data {
        let json = try JSONEncoder().encode(snapshot)
        return try (json as NSData).compressed(using: .zlib) as Data
    }

    /// Nil when the bytes aren't a payload this version can read; the copy
    /// is then treated as empty and replaced by the next save.
    nonisolated static func decode(_ payload: Data) -> DataStore.Snapshot? {
        guard let json = try? (payload as NSData).decompressed(using: .zlib) as Data else { return nil }
        return try? JSONDecoder().decode(DataStore.Snapshot.self, from: json)
    }

    private static func message(for error: Error) -> String {
        guard let cloudError = error as? CKError else {
            return "Couldn't reach iCloud. Vitala will try again."
        }
        switch cloudError.code {
        case .networkUnavailable, .networkFailure:
            return "No connection. Vitala will sync when you're back online."
        case .quotaExceeded:
            return "Your iCloud storage is full, so the latest changes couldn't be saved there."
        case .notAuthenticated, .accountTemporarilyUnavailable:
            return "iCloud couldn't confirm your account on this iPhone. Open the Settings app and tap your name: if it asks you to sign in again or review your account, do that. Vitala will keep trying."
        case .requestRateLimited, .serviceUnavailable, .zoneBusy:
            return "iCloud is busy. Vitala will try again shortly."
        case .serverRejectedRequest, .internalError, .serverResponseLost:
            return "iCloud had a problem on its side. Vitala will try again."
        case .badContainer:
            // The server doesn't know the container. Seen for hours after a
            // container is first created, before it reaches iCloud's servers.
            return "iCloud doesn't recognise Vitala's storage yet. When iCloud storage for an app has only just been set up this can take up to a day to clear. Vitala will keep trying."
        case .missingEntitlement, .permissionFailure:
            return "This copy of Vitala isn't set up to use iCloud. If you installed it from the App Store, please contact support."
        default:
            return "Couldn't reach iCloud. Vitala will try again."
        }
    }
}

/// Stands in for iCloud where it must not be used (see `usesCloudKit`).
struct NoCloud: CloudStateStore {
    func availability() async -> CloudAvailability { .unknown }
    func fetch() async throws -> CloudState? { nil }
    func save(_ state: CloudState) async throws -> Bool { false }
    func delete() async throws {}
}

/// The synced copy as one record in the user's private CloudKit database.
/// Only the user can read it; it never touches a server of Vitala's.
actor CloudKitStateStore: CloudStateStore {
    private static let recordType = "VitalaData"
    private static let payloadField = "payload"
    private static let versionField = "version"

    private let recordID = CKRecord.ID(recordName: "state")
    /// Made on first use, so an app that never syncs never opens CloudKit.
    private lazy var container = CKContainer(identifier: Self.containerIdentifier)
    /// The record as last fetched or saved; saving it back tells CloudKit
    /// which version this device has seen.
    private var known: CKRecord?

    /// The container named in the app's entitlements. Change both together.
    static let containerIdentifier = "iCloud.com.vitala.healthyliving"

    private var database: CKDatabase { container.privateCloudDatabase }

    func availability() async -> CloudAvailability {
        do {
            switch try await container.accountStatus() {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .temporarilyUnavailable: return .needsAttention
            default: return .unknown
            }
        } catch {
            return .unknown
        }
    }

    private static let log = Logger(subsystem: "com.vitala.healthyliving", category: "sync")

    func fetch() async throws -> CloudState? {
        Self.log.notice("Fetching from \(Self.containerIdentifier, privacy: .public)")
        do {
            let record = try await database.record(for: recordID)
            known = record
            guard let asset = record[Self.payloadField] as? CKAsset, let url = asset.fileURL else { return nil }
            let version = (record[Self.versionField] as? Int) ?? 1
            return CloudState(version: version, payload: try Data(contentsOf: url))
        } catch let error as CKError where error.code == .unknownItem {
            known = nil
            return nil
        }
    }

    func save(_ state: CloudState) async throws -> Bool {
        let record = known ?? CKRecord(recordType: Self.recordType, recordID: recordID)
        // CloudKit uploads large values from a file.
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("vitala-sync-\(UUID().uuidString)")
        try state.payload.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        defer { try? FileManager.default.removeItem(at: file) }
        record[Self.payloadField] = CKAsset(fileURL: file)
        record[Self.versionField] = state.version as NSNumber
        Self.log.notice("Saving \(state.payload.count) bytes, \(self.known == nil ? "new record" : "existing record", privacy: .public)")
        do {
            // Saving fails if the record changed since `known` was fetched.
            known = try await database.save(record)
            return true
        } catch let error as CKError where error.code == .serverRecordChanged {
            return false
        }
    }

    func delete() async throws {
        do {
            _ = try await database.deleteRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            // Nothing there to delete.
        }
        known = nil
    }
}
