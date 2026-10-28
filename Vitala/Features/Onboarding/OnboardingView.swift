import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: Int = 0

    @State private var firstName: String = ""
    @State private var lastName: String = ""

    private let marketingPages: [OnboardingPage] = [
        .init(art: .brand, tint: VitalaColor.primary,
              title: "A gentler path to wellness",
              body: "Vitala blends movement, food, sleep, and breath into one calm daily rhythm."),
        .init(art: .symbol("figure.mind.and.body"), tint: VitalaColor.mindful,
              title: "Tiny habits, big change",
              body: "Celebrate small wins — a glass of water, a five-minute walk, a deep breath."),
        .init(art: .symbol("lock.shield.fill"), tint: VitalaColor.coralText,
              title: "Your data, your rules",
              body: "Everything stays on this iPhone. Connect Apple Health only if you want to — no account needed.")
    ]

    private var totalPages: Int { marketingPages.count + 1 } // +1 for the form page
    private var isFormPage: Bool { page == marketingPages.count }
    private var canContinueFromForm: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()

            VStack(spacing: 0) {
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
            // Pre-populate if a profile already exists so users can edit instead of retype.
            if let p = profileStore.profile {
                let parts = p.displayName.split(separator: " ", maxSplits: 1).map(String.init)
                if firstName.isEmpty { firstName = parts.first ?? "" }
                if lastName.isEmpty  { lastName  = parts.count > 1 ? parts[1] : "" }
            }
        }
    }

    // MARK: Subviews

    private var topBar: some View {
        HStack {
            if page > 0 {
                GlassIconButton(systemName: "chevron.left", label: "Back") { go(to: page - 1) }
            }
            Spacer()
            if !isFormPage {
                Button("Skip") { go(to: marketingPages.count) }
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .buttonStyle(TapTargetButtonStyle())
                    .accessibilityHint("Skips to setting up your name")
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, VitalaSpacing.md)
        .padding(.top, VitalaSpacing.xs)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(i == page ? VitalaColor.primary : VitalaColor.muted.opacity(0.3))
                    .frame(width: i == page ? 22 : 8, height: 8)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: page)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(totalPages)")
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
                go(to: page + 1)
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
                        .accessibilityAddTraits(.isHeader)
                    Text("Vitala uses your name to personalize your day. Everything you enter stays on this device.")
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textSecondary)
                }
                .padding(.top, VitalaSpacing.md)

                VStack(spacing: VitalaSpacing.sm) {
                    VitalaTextField(title: "First name", text: $firstName,
                                    icon: "person", contentType: .givenName)
                    VitalaTextField(title: "Last name (optional)", text: $lastName,
                                    icon: "person", contentType: .familyName)
                }

                Label {
                    Text("Vitala is a wellness companion, not a medical device. For medical advice, talk to a healthcare professional.")
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(VitalaFont.caption(12))
                .foregroundStyle(VitalaColor.textSecondary)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
    }

    // MARK: Actions

    private func go(to newPage: Int) {
        withAnimation(reduceMotion ? nil : .default) { page = max(0, min(newPage, marketingPages.count)) }
    }

    private func saveAndContinue() async {
        let display = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
            .trimmingCharacters(in: .whitespaces)
        if var p = profileStore.profile {
            p.displayName = display
            try? await profileStore.saveProfile(p)
        } else {
            profileStore.createProfile(displayName: display)
        }
        appState.completeOnboarding()
    }
}

private struct OnboardingPage {
    enum Art {
        case brand
        case symbol(String)
    }
    let art: Art
    let tint: Color
    let title: String
    let body: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    private let artSize: CGFloat = 180

    var body: some View {
        ScrollView {
            VStack(spacing: VitalaSpacing.lg) {
                ZStack {
                    Circle().fill(page.tint.opacity(0.08)).frame(width: artSize * 1.35, height: artSize * 1.35)
                    Circle().fill(page.tint.opacity(0.14)).frame(width: artSize, height: artSize)
                    switch page.art {
                    case .brand:
                        BrandMark(size: artSize * 0.6)
                    case .symbol(let name):
                        Image(systemName: name)
                            .font(.system(size: artSize * 0.4, weight: .bold))
                            .foregroundStyle(page.tint)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, VitalaSpacing.xl)
                .accessibilityHidden(true)

                Text(page.title)
                    .font(VitalaFont.title(28))
                    .foregroundStyle(VitalaColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(page.body)
                    .font(VitalaFont.body(16))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VitalaSpacing.md)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .environmentObject(ProfileStore())
}
