import Foundation
import SwiftUI
import UIKit

/// Owns the user's profile. Vitala is local-first: the profile lives only on
/// this device and is created during onboarding — there is no account.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: UserProfile?
    /// Optional profile photo, stored only on this device.
    @Published private(set) var avatar: UIImage?

    nonisolated static let fileName = "profile.json"
    nonisolated static let avatarFileName = "avatar.jpg"
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

    /// Saves a new profile photo, downscaled so it stays small on disk.
    /// Returns false if the data isn't an image.
    @discardableResult
    func setAvatar(imageData: Data) -> Bool {
        guard let original = UIImage(data: imageData) else { return false }
        let image = Self.downscaled(original, maxSide: 600)
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return false }
        do {
            try files.saveData(jpeg, to: Self.avatarFileName)
            avatar = image
            return true
        } catch {
            return false
        }
    }

    func removeAvatar() {
        files.delete(Self.avatarFileName)
        avatar = nil
    }

    private static func downscaled(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Removes the profile from this device.
    func erase() {
        files.delete(Self.avatarFileName)
        avatar = nil
        files.delete(Self.fileName)
        defaults.removeObject(forKey: Self.legacyDefaultsKey)
        profile = nil
        isReadOnly = false
    }

    // MARK: Persistence

    private func load() {
        if let data = files.loadData(Self.avatarFileName) {
            avatar = UIImage(data: data)
        }
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
