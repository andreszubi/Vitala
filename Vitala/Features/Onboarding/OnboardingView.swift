import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var auth: AuthService
    @State private var page: Int = 0

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""

    private let marketingPages: [OnboardingPage] = [
        .init(icon: "leaf.fill", tint: VitalaColor.primary,
              title: "A gentler path to wellness",
              body: "Vitala blends movement, food, sleep, and breath into one calm daily rhythm."),
        .init(icon: "figure.mind.and.body", tint: VitalaColor.sage,
              title: "Tiny habits, big change",
              body: "We celebrate small wins — a glass of water, a 5-minute walk, a deep breath."),
        .init(icon: "heart.text.square.fill", tint: VitalaColor.coral,
              title: "Your data, your rules",
              body: "Sync with Apple Health when you're ready. Privacy is the default, not a setting.")
    ]

    private var totalPages: Int { marketingPages.count + 1 } // +1 for the form page
    private var isFormPage: Bool { page == marketingPages.count }
    private var canContinueFromForm: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@") && email.contains(".")
    }

    var body: some View {
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()

            VStack {
                topBar

                TabView(selection: $page) {
                    ForEach(Array(marketingPages.enumerated()), id: \.offset) { i, p in
                        OnboardingPageView(page: p).tag(i)
                    }
                    formPage.tag(marketingPages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                pageIndicator
                    .padding(.bottom, VitalaSpacing.lg)

                continueButton
                    .padding(.horizontal, VitalaSpacing.lg)
                    .padding(.bottom, VitalaSpacing.lg)
            }
        }
        .onAppear {
            // Pre-populate from existing demo profile so users can edit instead of retype.
            if let p = auth.profile {
                let parts = p.displayName.split(separator: " ", maxSplits: 1).map(String.init)
                if firstName.isEmpty { firstName = parts.first ?? "" }
                if lastName.isEmpty  { lastName  = parts.count > 1 ? parts[1] : "" }
                if email.isEmpty && !p.email.isEmpty && !p.email.contains("demo@vitala.app") {
                    email = p.email
                }
            }
        }
    }

    // MARK: Subviews

    private var topBar: some View {
        HStack {
            Spacer()
            if !isFormPage {
                Button("Skip") { skipToForm() }
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .padding(.horizontal, VitalaSpacing.lg)
        .padding(.top, VitalaSpacing.md)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(i == page ? VitalaColor.primary : VitalaColor.muted.opacity(0.3))
                    .frame(width: i == page ? 22 : 8, height: 8)
                    .animation(.spring(duration: 0.3), value: page)
            }
        }
    }

    @ViewBuilder
    private var continueButton: some View {
        if isFormPage {
            PrimaryButton(title: "Get started", icon: "sparkles",
                          isEnabled: canContinueFromForm) {
                Task { await saveAndContinue() }
            }
        } else {
            PrimaryButton(title: "Continue", icon: "arrow.right") {
                withAnimation { page += 1 }
            }
        }
    }

    private var formPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Let's get to know you")
                        .font(VitalaFont.title(28))
                        .foregroundStyle(VitalaColor.textPrimary)
                    Text("Your name and email help personalize Vitala. They stay on this device.")
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textSecondary)
                }
                .padding(.top, VitalaSpacing.md)

                VStack(spacing: VitalaSpacing.sm) {
                    HStack(spacing: 12) {
                        VitalaTextField(title: "First name", text: $firstName,
                                        icon: "person", contentType: .givenName)
                        VitalaTextField(title: "Last name", text: $lastName,
                                        icon: "person", contentType: .familyName)
                    }
                    VitalaTextField(title: "Email", text: $email, icon: "envelope",
                                    keyboard: .emailAddress, contentType: .emailAddress)
                }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
    }

    // MARK: Actions

    private func skipToForm() {
        withAnimation { page = marketingPages.count }
    }

    private func saveAndContinue() async {
        let display = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
            .trimmingCharacters(in: .whitespaces)
        if var p = auth.profile {
            p.displayName = display
            p.email = email.trimmingCharacters(in: .whitespaces)
            try? await auth.saveProfile(p)
        } else {
            await auth.signUp(email: email, password: "demo", displayName: display)
        }
        appState.completeOnboarding()
    }
}

private struct OnboardingPage {
    let icon: String
    let tint: Color
    let title: String
    let body: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: VitalaSpacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(page.tint.opacity(0.18)).frame(width: 200, height: 200)
                Circle().fill(page.tint.opacity(0.10)).frame(width: 280, height: 280)
                Image(systemName: page.icon)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(page.tint)
            }
            Spacer().frame(height: 12)
            Text(page.title)
                .font(VitalaFont.title(28))
                .foregroundStyle(VitalaColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(page.body)
                .font(VitalaFont.body(16))
                .foregroundStyle(VitalaColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .padding(.horizontal, VitalaSpacing.lg)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .environmentObject(AuthService())
}
