import Foundation
import SwiftUI

/// Owns the user's profile. Vitala is local-first: the profile lives only on
/// this device and is created during onboarding — there is no account.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: UserProfile?

    nonisolated static let fileName = "profile.json"
    /// Where the profile lived before 1.0. Read once, migrated, then removed.
    nonisolated static let legacyDefaultsKey = "vitala.demo.profile"

    private let files: SecureFileStore
    private let defaults: UserDefaults
    private var isReadOnly = false

    init(files: SecureFileStore = SecureFileStore(), defaults: UserDefaults = .standard) {
        self.files = files
        self.defaults = defaults
        load()
    }

    // MARK: Public API

    /// Creates the profile the first time the user finishes onboarding.
    func createProfile(displayName: String) {
        let p = UserProfile(id: UUID().uuidString, displayName: displayName)
        profile = p
        persist(p)
    }

    func saveProfile(_ profile: UserProfile) async throws {
        var updated = profile
        updated.updatedAt = .now
        self.profile = updated
        persist(updated)
    }

    /// Removes the profile from this device.
    func erase() {
        files.delete(Self.fileName)
        defaults.removeObject(forKey: Self.legacyDefaultsKey)
        profile = nil
        isReadOnly = false
    }

    // MARK: Persistence

    private func load() {
        switch files.load(UserProfile.self, from: Self.fileName) {
        case .loaded(let p):
            profile = p
        case .unreadable:
            isReadOnly = true
        case .missing:
            guard let data = defaults.data(forKey: Self.legacyDefaultsKey),
                  let legacy = try? JSONDecoder().decode(UserProfile.self, from: data) else {
                return
            }
            profile = legacy
            if (try? files.save(legacy, to: Self.fileName)) != nil {
                defaults.removeObject(forKey: Self.legacyDefaultsKey)
            }
        }
    }

    private func persist(_ profile: UserProfile) {
        guard !isReadOnly else { return }
        try? files.save(profile, to: Self.fileName)
    }
}
