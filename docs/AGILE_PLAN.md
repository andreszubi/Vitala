# Vitala 1.0 — Release Plan

Author: Andres Zubizarreta

This plan takes Vitala from a class-demo build to an App Store–ready 1.0. It is organised as a Scrum-style backlog: epics broken into user stories with acceptance criteria and story points, delivered across four one-week sprints, each ending with a working, tested build.

---

## 1. Audit — what is missing today

Findings from a full read of every source file and a clean build on Xcode 27.1 / iOS 27.1 SDK. Severity: **Blocker** = App Review rejection or crash risk, **High** = broken or misleading feature, **Medium** = quality/polish.

### App Store blockers

| # | Finding | Where |
|---|---------|-------|
| B1 | No app icon image. `AppIcon.appiconset` contains only `Contents.json`; uploads are rejected without a 1024×1024 icon. | `Resources/Assets.xcassets/AppIcon.appiconset` |
| B2 | No privacy manifest. The app uses `UserDefaults` (a "required reason" API); since May 2024 uploads without `PrivacyInfo.xcprivacy` are flagged/rejected. | — |
| B3 | HealthKit entitlement removed, but the app still requests HealthKit authorization. On device this throws, so Apple Health never connects. | `Vitala.entitlements`, `HealthKitService` |
| B4 | Placeholder and fake data shown as real: "Demo User", hard-coded streak "3", "87% weekly goal", "12 workouts / 48 mindful min", and a Progress screen built entirely from mock arrays with a range picker that does nothing. Guideline 2.1/2.3. | `DashboardView`, `ProfileView`, `ProgressDashboardView`, `AuthService` |
| B5 | Buttons that do nothing: "Export my data", "Delete account", dashboard bell, "Continue with Apple". Guideline 2.1 (completeness). | `SettingsView`, `DashboardView`, `SignInView` |
| B6 | Privacy policy text claims data is stored in Firestore — it isn't. Policy must be accurate and also hosted at a public URL for App Store Connect (required for HealthKit apps). | `SettingsView` |
| B7 | HealthKit read access requested for types the app never uses (body mass, height, basal energy, resting HR). Apple rejects HealthKit apps that request more than they need. | `HealthKitService` |
| B8 | Unused permission strings for Camera, Photo Library, and Motion — the app never uses those APIs. | `Info.plist` |

### Functional gaps and bugs

| # | Finding | Severity |
|---|---------|----------|
| F1 | Unreachable auth flow (Sign in / Sign up / Forgot password) and an unused `GoogleService-Info.plist`. The app is local-first; the dead code confuses the product story. | High |
| F2 | Onboarding requires an email address that is never used for anything. | High |
| F3 | All logs stored as one growing JSON blob in `UserDefaults` without file protection. Health data should live in a protected file. | High |
| F4 | HealthKit connection state isn't persisted, so after relaunch every write is silently skipped. | High |
| F5 | Editing a workout writes a *second* workout to Apple Health; deleting local entries never removes them from Health. | High |
| F6 | Closing an active workout with ✕ saves it, even after two seconds, with the full planned calories. | High |
| F7 | Mindful session "✓" after 5 seconds logs a 1-minute session. | Medium |
| F8 | Water entries can't be deleted or corrected. | High |
| F9 | Custom activity "distance" field is collected and thrown away; activity type isn't stored (guessed from the name). | Medium |
| F10 | Move ring goal is derived from the *food intake* calorie goal (÷4); exercise goal hard-coded to 30 min. | Medium |
| F11 | Edit profile saves *today* as the birthday if none was set; imperial height switches to "total inches" instead of ft/in. | High |
| F12 | "Daily reminders" toggle shows On when permission was never granted; turning it Off doesn't cancel notifications. Reminder times can't be changed. | High |
| F13 | Sign out wipes the profile but keeps all logs; there is no real "erase all data". | High |
| F14 | Sleep form accepts wake-before-bed and defaults to ~20-hour nights in the evening; sleep streak resets to 0 until today's entry exists. | Medium |
| F15 | `EditProfileView` wraps its own `NavigationStack` and is also pushed inside Settings' stack (nested stacks). | Medium |
| F16 | Version shown in Settings is hard-coded; Info.plist hard-codes version numbers instead of using build settings. | Medium |
| F17 | No unit tests or UI tests. | High |

### Design and polish

| # | Finding |
|---|---------|
| D1 | Six custom tabs squeeze labels to 9.5 pt; HIG recommends at most five. Native `TabView` would also pick up iOS 26+ Liquid Glass automatically. |
| D2 | Cards are styled five different ways (`vitalaCard`, `glassCard`, ad-hoc `background+clipShape+shadow`). Hairline strokes are `Color.black.opacity(0.05)`, invisible in Dark Mode. |
| D3 | Repeated colour literals (water blue, sleep indigo) instead of tokens. |
| D4 | White text on light gradients (workout covers, mindfulness player, primary button end-stop). |
| D5 | Splash runs 1.4 s on every launch. |

### Accessibility (WCAG 2.1 AA / Apple Accessibility)

| # | Finding |
|---|---------|
| A1 | Every font is a fixed point size — no Dynamic Type support anywhere. |
| A2 | Secondary text `#8A938F` on cream is **2.9:1** (needs 4.5:1). Coral text 2.5:1, success-green text 2.6:1, white-on-sage button text ≈3.6:1. |
| A3 | `VitalaTextField` and several `DatePicker`s have empty labels — VoiceOver reads "text field" with no name. |
| A4 | Tappable rows use `.onTapGesture` (Profile quick links, meal/sleep/activity rows) so VoiceOver doesn't expose them as buttons. |
| A5 | Icon-only buttons with no labels (workout player, session player, date navigator, remove-food). |
| A6 | Selected state of chips is conveyed by colour only (no `.isSelected` trait). |
| A7 | Touch targets below 44 pt (date chevrons 40, menus 28–32, close buttons 36, filter chips ≈35). |
| A8 | Headings aren't marked as headers; rings, charts, and the water glass have no accessible summary. |
| A9 | Animations ignore Reduce Motion (splash pulse, breathing circles, tab pill). |

---

## 2. Product decisions

1. **Local-first, no accounts for 1.0.** Data stays on the device (plus Apple Health with permission). This removes the need for sign-in, account deletion flows, and a server, and lets the privacy label be "Data Not Collected". Cloud sync moves to the backlog.
2. **iPhone-only for 1.0.** The layouts are phone layouts; shipping iPad would require iPad screenshots and a dedicated layout pass. iPad stays in the backlog.
3. **Five tabs.** Today · Activity · Nutrition · Mindful · Sleep. Profile and Settings move behind the avatar on Today.
4. **Accessibility is part of Done**, not a separate phase: every screen touched in a sprint must meet the a11y checklist before the story closes. Sprint 3 adds automated `performAccessibilityAudit()` UI tests as a regression net.

---

## 3. Definition of Done

A story is done when:

- It builds with no new warnings on the current Xcode.
- Unit tests for any logic it adds pass; UI/accessibility audit tests pass for any screen it touches.
- It works in Light and Dark Mode and at the largest accessibility text size without clipped or overlapping text.
- Every interactive element has an accessible name, correct traits, and a ≥44 pt target; text contrast ≥4.5:1.
- No placeholder copy, mock data, or dead buttons remain in the touched screens.
- It is committed on the release branch with a descriptive message.

---

## 4. Backlog

Points use a Fibonacci scale. Priority uses MoSCoW.

### Epic E1 — Foundation & data integrity

| ID | Story | Acceptance criteria | Pts | Pri |
|----|-------|---------------------|-----|-----|
| E1-1 | As a developer, I want the Xcode project to pick up new files automatically and have test targets, so the team can add code and tests without regenerating the project. | Project uses folder-synchronized groups; `VitalaTests` (Swift Testing) and `VitalaUITests` targets exist and run from the `Vitala` scheme. | 3 | Must |
| E1-2 | As a user, I want my health logs stored securely on my device. | Data saved as JSON in Application Support with complete file protection; existing UserDefaults data migrates once on first launch; unit-tested round trip and migration. | 5 | Must |
| E1-3 | As a user, I want the app to remember that I connected Apple Health. | Connection state persisted; writes resume after relaunch; only the HealthKit types the app uses are requested; usage strings match exactly. | 3 | Must |
| E1-4 | As a user, editing or deleting a log should update Apple Health too. | Samples carry a sync identifier; edits replace, deletes remove; no duplicate workouts in Health. | 5 | Must |
| E1-5 | As a user, I don't want an account to use a private, on-device wellness app. | Dead auth screens and Firebase leftovers removed; onboarding asks only for a name; no "demo" wording anywhere. | 3 | Must |

### Epic E2 — Feature completeness

| ID | Story | Acceptance criteria | Pts | Pri |
|----|-------|---------------------|-----|-----|
| E2-1 | As a user, I want my streak and weekly progress to reflect what I actually did. | Streak = consecutive days with any log; weekly goal = workouts this week vs target; profile totals computed from data; unit-tested. | 3 | Must |
| E2-2 | As a user, I want a Progress screen built from my real data. | Week/Month ranges; steps (Health), active minutes, calories eaten, water, sleep, mindful minutes; 28-day consistency grid; empty states when no data. | 8 | Must |
| E2-3 | As a user, I want to choose which reminders I get and when. | Per-reminder toggle + time; reflects real notification permission; turning off cancels pending requests; deep link to Settings when denied. | 5 | Must |
| E2-4 | As a user, I want to export or erase all my data. | Export produces a JSON file via the share sheet; Erase asks for confirmation, wipes profile, logs and reminders, and returns to onboarding. | 3 | Must |
| E2-5 | As a user, I want to fix mistakes in water, sleep and activity logs. | Water entries deletable; sleep validates wake > bed and < 24 h with sensible defaults; activity stores type and distance. | 5 | Must |
| E2-6 | As a user, I want guided workouts and breathing sessions to behave honestly. | Close asks Save / Discard; calories scale with time spent; timed exercises count down and auto-advance; sessions under one minute aren't logged; screen stays awake during sessions. | 5 | Must |
| E2-7 | As a user, I want my Move and Exercise ring goals to be separate from my food goal. | New `dailyActiveKcal`, `dailyExerciseMinutes` goals with backward-compatible decoding; editable in Goals. | 2 | Should |
| E2-8 | As a user, I want my profile edits to be safe and consistent. | Birthday optional until set; ft/in in imperial; Save in toolbar; no nested navigation stacks. | 2 | Must |

### Epic E3 — Visual polish

| ID | Story | Acceptance criteria | Pts | Pri |
|----|-------|---------------------|-----|-----|
| E3-1 | As a user, I want a consistent, calm visual language. | One card style, adaptive hairlines, colour tokens for water/sleep/success/coral-text; no stray literals. | 3 | Must |
| E3-2 | As a user, I want familiar, roomy navigation. | Native 5-tab `TabView`; Profile behind avatar on Today; Settings from Profile. | 3 | Must |
| E3-3 | As a user, I want the app to feel responsive and alive. | Success haptics on logging; short, motion-aware splash; consistent empty states. | 2 | Should |
| E3-4 | As a user, I want a recognisable app icon. | Original 1024×1024 opaque icon (no SF Symbols, per the SF Symbols licence). | 2 | Must |

### Epic E4 — Accessibility

| ID | Story | Acceptance criteria | Pts | Pri |
|----|-------|---------------------|-----|-----|
| E4-1 | As a low-vision user, I want text to follow my preferred size. | Type ramp built on text styles; layouts reflow (grids collapse, rows stack) at accessibility sizes. | 5 | Must |
| E4-2 | As a low-vision user, I want readable contrast. | All text tokens ≥4.5:1 on their backgrounds in Light and Dark; buttons use a dedicated fill colour. | 3 | Must |
| E4-3 | As a VoiceOver user, I want every control named and every chart summarised. | Labels, values, hints, header traits, selected traits, custom actions for edit/delete, combined elements for cards, announcements for breathing phases. | 8 | Must |
| E4-4 | As a user with motor or vestibular needs, I want big targets and calm motion. | 44 pt minimum targets; Reduce Motion respected. | 2 | Must |
| E4-5 | As a team, we want accessibility regressions caught automatically. | UI tests run `performAccessibilityAudit()` on onboarding and each main screen. | 3 | Must |

### Epic E5 — Release readiness

| ID | Story | Acceptance criteria | Pts | Pri |
|----|-------|---------------------|-----|-----|
| E5-1 | As the publisher, I want the binary to pass upload validation. | Privacy manifest, HealthKit entitlement, scene manifest, `ITSAppUsesNonExemptEncryption`, versions from build settings, iPhone-only, unused permission strings removed. | 3 | Must |
| E5-2 | As the publisher, I want accurate legal pages. | In-app privacy policy and terms rewritten for the local-first app; hostable `docs/privacy-policy.md` and `docs/support.md`. | 2 | Must |
| E5-3 | As the publisher, I want listing copy and a submission checklist. | `docs/APP_STORE.md`: name, subtitle, description, keywords, category, age rating, privacy label answers, review notes, screenshot list, and the manual steps only the account holder can do. | 2 | Must |
| E5-4 | As the publisher, I want App Store screenshots that look real. | DEBUG-only launch argument seeds realistic sample data for screenshots and UI tests. | 2 | Should |

### Later (not in 1.0)

- iCloud / CloudKit sync across devices.
- iPad layout and Mac Catalyst.
- Localization (String Catalog is ready once strings are final).
- Food database / barcode scanning.
- Apple Watch companion for the workout timer.
- Home Screen widgets and App Intents (Shortcuts: "Log 250 ml of water").

---

## 5. Sprint plan

| Sprint | Goal | Stories | Points |
|--------|------|---------|--------|
| **Sprint 1 — Trustworthy core** | Nothing the app says is fake or lost. | E1-1, E1-2, E1-3, E1-4, E1-5, E2-5, E2-8 | 26 |
| **Sprint 2 — Complete features** | Every button does what it says. | E2-1, E2-2, E2-3, E2-4, E2-6, E2-7 | 26 |
| **Sprint 3 — Polish + accessibility** | Looks finished; works for everyone. | E3-1…E3-4, E4-1…E4-5 | 31 |
| **Sprint 4 — Ship it** | A binary and listing ready for App Review. | E5-1…E5-4 | 9 |

Each sprint closes with a review (clean build, tests, simulator walkthrough in Light/Dark and large text) and a retrospective note in this file.

---

## 6. Sprint log

### Sprint 1 — Trustworthy core ✅

Delivered E1-1…E1-5, E2-5 and E2-8.

- Project moved to folder-synchronised groups; `VitalaTests` and `VitalaUITests` added; the pbxproj generator retired.
- Auth screens and Firebase leftovers removed; services renamed `ProfileStore` / `DataStore`; onboarding asks only for a name.
- Logs and profile moved from `UserDefaults` to protected files with one-time migration and a never-overwrite-unreadable-data guard.
- Apple Health: minimal read/write types, connection state derived from HealthKit, sync identifiers so edits replace and deletes remove.

**Scope change:** the design-system foundation (E3-1, E4-1, E4-2) was pulled into Sprint 1 so each screen could get functional, visual and accessibility fixes in a single pass instead of being reworked three times.

**Retro:** building from a synced scratch copy avoided fighting Xcode's lock on the open project; keep that for CI-style runs.

### Sprint 2 — Complete features ✅

Delivered E2-1…E2-4, E2-6, E2-7.

- Real streaks, weekly progress and profile totals; Progress rebuilt from real data with 7/30-day ranges.
- Reminders with per-reminder times and honest permission state; Export (JSON) and Erase all data.
- Honest workout and breathing players (Save / Discard, calories scaled to time, countdowns, no sub-minute logs).
- Separate Move / Exercise / mindful goals with backward-compatible decoding; calorie suggestion from the profile.

### Sprint 3 — Polish + accessibility ✅

Delivered E3-1…E3-4 and E4-1…E4-5, plus stakeholder requests raised during the sprint:

- **Native Liquid Glass** (requested): system glass buttons, chips in a glass container, glass players and date navigator, scroll-edge bars, glass keyboard Done bar, minimizing tab bar; iOS 17–25 fallback.
- **Glass app icon** (requested, three review rounds): Icon Composer `.icon` — frosted two-leaf sprout with a reflective glass rim; matching in-app brand mark.
- **Calming session sound** (requested): spa pad, ocean and binaural tones synthesised on device, following the breath.
- **Profile photo** and **Profile on every tab** (requested).
- Accessibility: darker text tokens, `ContrastTests`, labels and hints, 44 pt targets, Audio Graph chart descriptors, Reduce Motion. Xcode accessibility audits pass on every main screen at default and large text sizes.

**Retro:** the pixel-sampling contrast audit misreads text over translucent glass; token-level contrast tests are the reliable gate. Labels that differ from visible text trigger "clipped text" — keep extra context in hints.

### Sprint 4 — Ship it ✅

Delivered E5-1…E5-4.

- Privacy manifest, versioning from build settings, export-compliance flag, scene manifest, iPhone-only.
- Hostable privacy policy and support pages (`docs/`), App Store submission kit (`docs/APP_STORE.md`), refreshed README.
- 6.9" screenshots generated by `ScreenshotTests` from seeded data; dismissible Apple Health prompt.
- Release build for devices verified; full suite green.

**Remaining manual steps (account holder):** developer team and bundle ID, GitHub Pages, App Store Connect record, TestFlight device QA, submission — see `docs/APP_STORE.md`.

---

## 7. Next backlog (1.1+)

| Priority | Item |
|---|---|
| High | **Food database search and barcode scanning** — USDA FoodData Central for search (free key, public-domain data) and Open Food Facts for barcodes via the VisionKit scanner, cached locally. Requires updating the privacy policy and App Privacy answers because searches leave the device. |
| High | iCloud / CloudKit sync across devices |
| Medium | Home Screen widgets and App Intents ("Log 250 ml of water") |
| Medium | iPad layout |
| Medium | Localization (String Catalog) |
| Low | Apple Watch companion for workouts and breathing |
