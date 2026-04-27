import Foundation
import SwiftUI

/// Demo-mode error type. Kept for compatibility with views that show
/// `auth.lastError`, even though we never produce one locally.
enum AuthError: LocalizedError {
    case invalidEmail, weakPassword, wrongPassword, userNotFound, networkError, unknown(String)
    var errorDescription: String? {
        switch self {
        case .invalidEmail: "That email doesn't look right."
        case .weakPassword: "Pick a stronger password (at least 8 characters)."
        case .wrongPassword: "That password is incorrect."
        case .userNotFound: "No account found for that email."
        case .networkError: "Network unavailable. Try again."
        case .unknown(let m): m
        }
    }
}

/// LOCAL-ONLY AuthService for class demo.
/// No Firebase. Profile is auto-created on first launch and persisted in UserDefaults.
/// Public interface intentionally matches the old Firebase version so views need
/// no changes.
@MainActor
final class AuthService: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading: Bool = false
    @Published var lastError: AuthError?

    private let storageKey = "vitala.demo.profile"

    init() {
        loadOrCreateDemoProfile()
    }

    // MARK: Public API (matches old Firebase signatures)

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true; defer { isLoading = false }
        try? await Task.sleep(nanoseconds: 250_000_000) // mimic network
        let p = UserProfile(
            id: UUID().uuidString,
            email: email.isEmpty ? "demo@vitala.app" : email,
            displayName: displayName.isEmpty ? "Demo" : displayName
        )
        self.profile = p
        persist(p)
    }

    func signIn(email: String, password: String) async {
        isLoading = true; defer { isLoading = false }
        try? await Task.sleep(nanoseconds: 250_000_000)
        if profile == nil {
            let p = UserProfile(
                id: UUID().uuidString,
                email: email.isEmpty ? "demo@vitala.app" : email,
                displayName: emailToName(email)
            )
            profile = p
            persist(p)
        }
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        profile = nil
        loadOrCreateDemoProfile()
    }

    func sendPasswordReset(email: String) async {
        // No-op in demo mode.
    }

    func loadProfile(uid: String) async {
        // No-op in demo mode — profile is already loaded from UserDefaults.
    }

    func saveProfile(_ profile: UserProfile) async throws {
        var updated = profile
        updated.updatedAt = .now
        self.profile = updated
        persist(updated)
    }

    // MARK: Demo helpers

    private func loadOrCreateDemoProfile() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
            return
        }
        let demo = UserProfile(
            id: UUID().uuidString,
            email: "demo@vitala.app",
            displayName: "Demo User"
        )
        profile = demo
        persist(demo)
    }

    private func persist(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func emailToName(_ email: String) -> String {
        guard !email.isEmpty else { return "Friend" }
        let local = email.components(separatedBy: "@").first ?? email
        return local.capitalized
    }
}
