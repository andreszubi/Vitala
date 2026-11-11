import Foundation
import OSLog
import Security

/// Keeps the session in the Keychain: encrypted, on this device only, and
/// readable after the first unlock so the app can start signed in.
struct KeychainCredentialStore: CredentialStore {
    private let service = "com.vitala.healthyliving.account"
    private let account = "session"

    private static let log = Logger(subsystem: "com.vitala.healthyliving", category: "auth")

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func load() -> AuthSession? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func save(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status != errSecSuccess {
            Self.log.error("Couldn't save the session to the Keychain: \(status)")
        }
    }

    func clear() {
        SecItemDelete(query as CFDictionary)
    }
}

/// Keeps the session only while the app runs. For tests.
final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: AuthSession?

    init(_ session: AuthSession? = nil) {
        self.session = session
    }

    func load() -> AuthSession? {
        lock.lock(); defer { lock.unlock() }
        return session
    }

    func save(_ session: AuthSession) {
        lock.lock(); defer { lock.unlock() }
        self.session = session
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        session = nil
    }
}
