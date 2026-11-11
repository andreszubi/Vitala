import SwiftUI

struct RootView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var notifications: NotificationService

    @ObservedObject private var store = DataStore.shared
    @State private var didSplash = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var slide: AnyTransition { reduceMotion ? .opacity : .move(edge: .trailing) }

    var body: some View {
        ZStack {
            VitalaColor.background.ignoresSafeArea()

            switch appState.route {
            case .splash:
                SplashView(onFinish: { Task { await resolve() } })
                    .transition(.opacity)
            case .signIn:
                AuthView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView()
                    .transition(slide)
            case .profileSetup:
                ProfileSetupRootView()
                    .transition(slide)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: appState.route)
        .alert(storageNotice?.title ?? "", isPresented: Binding(get: { storageNotice != nil && didSplash },
                                                                 set: { if !$0 { acknowledgeNotice() } }),
               presenting: storageNotice) { _ in
            Button("OK", role: .cancel) {}
        } message: { notice in
            Text(notice.message)
        }
        .task(id: profileStore.profile?.id) {
            // Re-route whenever the profile is created or erased.
            if didSplash { route() }
        }
        .onChange(of: auth.account?.id) { _, _ in
            // Signing in, signing out, or deleting the account.
            if didSplash { route() }
        }
        // Built only when there is something to ask: an alert's buttons and
        // message otherwise sit in the accessibility tree of every screen.
        .alert("This iPhone has someone else's data",
               isPresented: Binding(get: { didSplash && auth.otherOwner != nil }, set: { _ in }),
               presenting: didSplash ? auth.otherOwner : nil) { _ in
            Button("Erase it and continue", role: .destructive, action: startFresh)
            Button("Sign out", role: .cancel) { auth.signOut() }
        } message: { owner in
            Text("Vitala on this iPhone holds the data of \(owner). To use it as \(auth.account?.email ?? "this account"), that data has to be erased from this iPhone first. Sign out to leave it as it is.")
        }
    }

    /// A data file that had to be repaired at launch, logs first.
    private var storageNotice: StorageNotice? { store.notice ?? profileStore.notice }

    private func acknowledgeNotice() {
        if store.notice != nil { store.acknowledgeNotice() } else { profileStore.acknowledgeNotice() }
    }

    private func resolve() async {
        didSplash = true
        route()
    }

    private func route() {
        appState.resolveRoute(profile: profileStore.profile, isSignedIn: auth.allowsEntry)
    }

    /// A different person has signed in: clear the last person's data from
    /// this device, then it is theirs. iCloud is left alone: it belongs to
    /// the Apple Account, not the Vitala one.
    private func startFresh() {
        CloudSync.shared.setOn(false)
        DataStore.shared.eraseAll()
        notifications.reset()
        profileStore.erase()
        auth.claimDevice()
        appState.resetAfterErase(isSignedIn: auth.allowsEntry)
    }
}
