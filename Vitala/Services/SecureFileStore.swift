import Foundation
import OSLog

/// Reads and writes Codable values as JSON files in Application Support.
/// Writes are atomic, and iOS Data Protection keeps the files encrypted until
/// the device is first unlocked after a restart.
struct SecureFileStore {
    enum LoadResult<T> {
        case missing
        case loaded(T)
        /// The file exists but couldn't be read or decoded. Callers must not
        /// overwrite it, or they'd destroy data that may still be recoverable.
        case unreadable
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

    func load<T: Decodable>(_ type: T.Type, from name: String) -> LoadResult<T> {
        let fileURL = url(for: name)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .missing }
        do {
            let data = try Data(contentsOf: fileURL)
            return .loaded(try JSONDecoder().decode(T.self, from: data))
        } catch {
            Self.log.error("Couldn't read \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .unreadable
        }
    }

    func save<T: Encodable>(_ value: T, to name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url(for: name),
                       options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(for: name))
    }
}
