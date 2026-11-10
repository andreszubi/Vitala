import Foundation
import OSLog

/// Reads and writes Codable values as JSON files in Application Support.
/// Writes are atomic, and iOS Data Protection keeps the files encrypted until
/// the device is first unlocked after a restart.
struct SecureFileStore {
    enum LoadResult<T> {
        case missing
        case loaded(T)
        /// The file's bytes couldn't be read at all, as happens before the
        /// device's first unlock after a restart. The file itself may be
        /// fine: leave it alone and try again later.
        case unreadable
        /// The bytes were read but aren't the JSON we expect. The file can
        /// be set aside (see `setAside`) and replaced.
        case damaged
    }

    let directory: URL

    private static let log = Logger(subsystem: "com.vitala.healthyliving", category: "storage")

    init(directory: URL = SecureFileStore.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Vitala", isDirectory: true)
    }

    func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: name).path)
    }

    func load<T: Decodable>(_ type: T.Type, from name: String) -> LoadResult<T> {
        guard exists(name) else { return .missing }
        let data: Data
        do {
            data = try Data(contentsOf: url(for: name))
        } catch {
            Self.log.error("Couldn't read \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .unreadable
        }
        do {
            return .loaded(try JSONDecoder().decode(T.self, from: data))
        } catch {
            Self.log.error("Couldn't decode \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .damaged
        }
    }

    func save<T: Encodable>(_ value: T, to name: String) throws {
        try saveData(try JSONEncoder().encode(value), to: name)
    }

    /// Raw bytes (e.g. an image), with the same protection as JSON files.
    func saveData(_ data: Data, to name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url(for: name),
                       options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func loadData(_ name: String) -> Data? {
        try? Data(contentsOf: url(for: name))
    }

    func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(for: name))
    }

    func modificationDate(_ name: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url(for: name).path))?[.modificationDate] as? Date
    }

    /// Replaces `copy` with the current contents of `name`.
    func copy(_ name: String, to copy: String) {
        guard let data = loadData(name) else { return }
        try? saveData(data, to: copy)
    }

    // MARK: Damaged files

    /// Marks a file that was moved out of the way because it couldn't be
    /// decoded: "logs.damaged-20261110-153000.json".
    static let damagedMarker = ".damaged-"

    private func damagedName(for name: String, at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let file = name as NSString
        let stem = file.deletingPathExtension + Self.damagedMarker + formatter.string(from: date)
        var candidate = stem + "." + file.pathExtension
        var attempt = 1
        while exists(candidate) {
            attempt += 1
            candidate = "\(stem)-\(attempt).\(file.pathExtension)"
        }
        return candidate
    }

    /// Moves a damaged file out of the way without deleting it, so a fresh
    /// one can be written and the old one can still be sent to support.
    /// Returns the name it was given, or nil if it couldn't be moved.
    @discardableResult
    func setAside(_ name: String, now: Date = .now) -> String? {
        let kept = damagedName(for: name, at: now)
        do {
            try FileManager.default.moveItem(at: url(for: name), to: url(for: kept))
            return kept
        } catch {
            Self.log.error("Couldn't set aside \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Keeps a copy of a file that is about to be rewritten without the
    /// entries that couldn't be read.
    @discardableResult
    func keepDamagedCopy(of name: String, now: Date = .now) -> String? {
        guard let data = loadData(name) else { return nil }
        let kept = damagedName(for: name, at: now)
        return (try? saveData(data, to: kept)) != nil ? kept : nil
    }

    /// Files set aside by `setAside` or `keepDamagedCopy`, oldest first.
    var damagedFiles: [URL] {
        let all = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return all.filter { $0.lastPathComponent.contains(Self.damagedMarker) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func deleteDamagedFiles() {
        damagedFiles.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}

/// An array that keeps every element it can decode and counts the ones it
/// can't, so one bad entry never hides the rest of a list.
struct Salvaged<Element: Decodable>: Decodable {
    var elements: [Element] = []
    var skipped = 0

    /// Stands in for an element that wouldn't decode, to step past it.
    private struct Unreadable: Decodable {
        init(from decoder: Decoder) throws {}
    }

    init(from decoder: Decoder) throws {
        var list = try decoder.unkeyedContainer()
        while !list.isAtEnd {
            if let element = try? list.decode(Element.self) {
                elements.append(element)
            } else {
                _ = try? list.decode(Unreadable.self)
                skipped += 1
            }
        }
    }
}

extension KeyedDecodingContainer {
    /// Decodes a list entry by entry. A missing key is an empty list; a
    /// value that isn't a list at all counts as one entry lost.
    func salvage<Element: Decodable>(_ type: Element.Type, forKey key: Key,
                                     skipped: inout Int) -> [Element] {
        guard contains(key), (try? decodeNil(forKey: key)) != true else { return [] }
        guard let list = try? decode(Salvaged<Element>.self, forKey: key) else {
            skipped += 1
            return []
        }
        skipped += list.skipped
        return list.elements
    }
}

/// Saves the newest value handed to it on a background queue. Changes made
/// in quick succession become one write, and `flush()` writes whatever is
/// waiting before it returns.
final class BackgroundSaver<Value>: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.vitala.background-saver", qos: .utility)
    private let lock = NSLock()
    private var pending: Value?
    private var scheduled = false
    private let delay: TimeInterval
    private let write: (Value) throws -> Void

    private static var log: Logger { Logger(subsystem: "com.vitala.healthyliving", category: "storage") }

    /// `write` runs on the saver's own queue, never on the caller's.
    init(delay: TimeInterval = 0.4, write: @escaping (Value) throws -> Void) {
        self.delay = delay
        self.write = write
    }

    /// Queues `value` to be written shortly, replacing any value still waiting.
    func save(_ value: Value) {
        lock.lock()
        pending = value
        let needsScheduling = !scheduled
        scheduled = true
        lock.unlock()
        guard needsScheduling else { return }
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in self?.writePending() }
    }

    /// Writes anything waiting, now, and returns once it is on disk.
    func flush() {
        queue.sync { writePending() }
    }

    /// Drops anything waiting and lets a write already under way finish.
    func cancel() {
        lock.lock()
        pending = nil
        lock.unlock()
        queue.sync {}
    }

    /// Runs `work` on the saver's queue, after any write already queued.
    func afterWrites(_ work: @escaping () -> Void) {
        queue.async(execute: work)
    }

    private func writePending() {
        lock.lock()
        let value = pending
        pending = nil
        scheduled = false
        lock.unlock()
        guard let value else { return }
        do {
            try write(value)
        } catch {
            Self.log.error("Couldn't save: \(error.localizedDescription, privacy: .public)")
        }
    }
}
