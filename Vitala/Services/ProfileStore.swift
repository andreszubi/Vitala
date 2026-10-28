import Foundation
import SwiftUI

/// Owns the user's profile. Vitala is local-first: the profile lives only on
/// this device and is created during onboarding — there is no account.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: UserProfile?

    private let storageKey = "vitala.demo.profile"

    init() {
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
        UserDefaults.standard.removeObject(forKey: storageKey)
        profile = nil
    }

    // MARK: Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return
        }
        profile = decoded
    }

    private func persist(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
