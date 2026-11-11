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
- ~~Food database / barcode scanning.~~ Delivered in Sprint 5.
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

### Sprint 5 — Stakeholder requests and device feedback ✅

Requests raised after the 1.0 build, plus issues found testing on a real iPhone. Same Definition of Done: unit tests, accessibility audits and a simulator walkthrough for every story.

| ID | Story | Acceptance criteria | Pts |
|----|-------|---------------------|-----|
| E6-1 | As a user, I want to find foods instead of typing nutrition by hand. | Search USDA FoodData Central with real portions; recent and custom foods work offline; online search can be turned off; API key kept out of Git (`Config/Secrets.xcconfig`). | 8 |
| E6-2 | As a user, I want to scan packaged food. | VisionKit barcode scanner with USDA lookup and Open Food Facts fallback; manual number entry when the camera isn't available; camera usage string added. | 5 |
| E6-3 | As a VoiceOver user, I want every form field named. | Every text field has a visible label and an accessible name; audits cover each form sheet. | 3 |
| E6-4 | As a user, I want the breathing cue to change with the count. | "Breathe in / Hold / Breathe out" switches within 0.2 s of the phase change; only the circles animate over the whole phase. | 1 |
| E6-5 | As a user with Apple Watch or another food app, I want that data in Vitala. | Last 30 days of sleep grouped into nights (time asleep, or time in bed when that's all there is) and dietary energy/macros grouped into meals; shown read-only and marked "Apple Health"; a night logged in Vitala wins over an overlapping one; Vitala's own samples skipped; privacy texts updated. | 5 |
| E6-6 | As a user, I want to keep a mood journal. | Entry with a mood from a menu, free text and a date; written any time or from a new session-complete screen (linked to that session); browse by day, edit, delete; included in export and erase; stored only on device. | 5 |

**Found in device testing:** sleep and nutrition from Apple Health never appeared (E6-5) and the breathing cue lagged the countdown (E6-4). Both were missed in the simulator, which has no Health data and a forgiving sense of timing — the TestFlight QA list now covers them.

**Retro:** a phase-length animation attached to a whole view also animates its text; scope long animations to the shapes they're meant for. Read-only imported entries needed a row without Edit/Delete, so `EditableRow` now accepts neither.

### Sprint 6 — Calmer sessions and richer nutrition ✅

| ID | Story | Acceptance criteria | Pts |
|----|-------|---------------------|-----|
| E7-1 | As a user, I want sounds that really differ. | Binaural tones audible over the spa pad; crystal singing bowls; a Spa, binaural & bowls mix that every session starts on; tests check each sound is distinct and never clips. | 5 |
| E7-2 | As a user, I want a peaceful scene behind the breathing guide. | Five scenes drawn live (ocean, rain, stars, mist, aurora), each session opening on its matching one; still under Reduce Motion; light enough not to delay taps. | 5 |
| E7-3 | As a user, I want to feel the breath. | Core Haptics that gently quicken and strengthen through the in-breath and ease off through the out-breath; every tap strong enough to feel; on/off switch; rejoins mid-breath. | 5 |
| E7-4 | As a user, I want fresh, fitting guidance. | About 14 cues per kind of session plus lines per session, shuffled each time, no repeats, never opening on the last session's first cue. | 2 |
| E7-5 | As a user, I want to see what I ate in detail. | Full food names with brand; fiber, sugar, sodium and the kinds of fat stored and totalled; "Not listed" when unknown; nutrition for each food and each meal section. | 8 |
| E7-6 | As a user, I want the player to respond to every tap. | Menus kept out of the countdown's redraws; audio session work off the main thread with one shared queue. | 3 |

**Found in device testing:** the sound menu dropped taps and showed the wrong choice, audio flickered when a session opened, and Xcode flagged audio-session hang risks. All traced to the player redrawing four times a second and to audio work on the main thread (E7-6). The decomposition and "cannot add handler" log lines that remain come from iOS's own glass animations.

**Retro:** the aurora took several rounds of feedback; once the preferred look was found, it was committed before adding detail, so it could always be restored. Haptics were tuned on device in small steps — taps under about 30% strength can't be felt on an iPhone.

---

### Sprint 7 — Dependable, with restaurants and exercise demonstrations ✅

**Sprint goal:** fix what a full code audit and device use turned up, and deliver the two features asked for: restaurant meals in food search and a demonstration for every exercise.

| ID | Story | Acceptance criteria | Pts |
|----|-------|---------------------|-----|
| E8-1 | As a user, I want changing the sound to be seamless. | Each layer of the sound glides to its new level over about a tenth of a second instead of jumping; a ringing bowl fades rather than being cut; a test switches sounds six times and fails if any step is large enough to hear as a click; rendering stays far faster than real time. | 3 |
| E8-2 | As a user, I want to log meals from restaurants. | Typing a chain's name lists its menu (20 chains USDA covers); restaurant items in any search are labelled with their chain and a takeaway icon; lab-analysed items load their real serving ("1 item 7.6 oz") when opened; shouted USDA names are tidied ("BIG MAC" reads "Big Mac"); chains can be browsed from chips under the search field; a note says figures are USDA's and menus change. | 8 |
| E8-3 | As a user, I want to see how each exercise is done. | All 19 library exercises have a looping demonstration; it plays in the workout player and pauses with it; each exercise in a workout's list shows a still and opens a closer look with instructions and play/pause; holds still under Reduce Motion; a filmed clip named after the exercise plays instead when one is bundled, silently and without interrupting the user's music. | 8 |
| E8-4 | As a user, I want the app to be dependable. | Two independent reviews of every source file (screens, then services and models); every high and medium finding fixed or scheduled; pure logic covered by tests; unit tests and accessibility audits green. | 8 |

**How the sprint ran**

1. *Refinement.* The four requests became the stories above. Two decisions were made up front:
   - **Restaurants** use USDA FoodData Central, which the app already talks to, so no new service, key or privacy disclosure is needed. Its limits are known and listed in the backlog.
   - **Exercise "videos"** ship as demonstrations drawn in the app, because there is no footage Vitala has the right to bundle. The player already prefers a filmed clip when one is present, so adding footage later needs no code.
2. *Build.* Each story was built, tested and pushed on its own: sound (E8-1), restaurants (E8-2), demonstrations (E8-3), audit fixes (E8-4).
3. *Review.* 110 unit tests, the accessibility audits, and a simulator walkthrough of restaurant search, the exercise list, the closer look, the workout player and a stand-in filmed clip.

**Audit (E8-4): what was found and fixed**

| Area | Fixed this sprint |
|---|---|
| Wrong data | Tabs left open overnight kept logging to yesterday. Heights just under a whole foot lost a foot (182 cm read 5' 0") and were saved back that way. Edit profile rewrote height and weight from rounded values. Progress counted going *over* the calorie target as meeting the goal. Logged distance ignored the app's units. A new activity ended in the future; editing a tracked workout dropped its seconds. Streaks and day charts broke where clocks change at midnight. Sleep could read "7h 60m". |
| Breathing sessions | Restart while paused stayed silent. Time in the background counted as breathing and could save a session nobody did. A session or workout could save itself behind the "End?" question. Sound did not come back after headphones were plugged in or a call ended, and ticked when it stopped. Scene motion jumped once a day. |
| Crashes | Very large or non-numeric amounts in custom food and water. |
| Speed | Settings re-encoded the whole export on every redraw. Every Health refresh redrew every screen whether anything changed, and history was re-read on each tab visit. Cue decks were dealt and audio engines created for views never shown. Scene colours were parsed from text many times a frame. |
| Cleanup | Library workouts and sessions keep the same ids between launches. Unused store methods, model fields and a model type removed. Exercise prescription text has one home. Reminder changes can no longer overtake one another. |

Findings that were not fixed are in the backlog below, marked *audit*.

**Not verified on a device:** the sound crossfade by ear, sound recovering after a headphone or call interruption, and haptics. These need a real iPhone; the simulator cannot show them.

**Retro:** rendering each demonstration to a contact sheet before putting it in the app caught unreadable poses (a forward fold with the head hidden behind an arm) in seconds rather than after a build. Giving the figure joint angles instead of positions means limbs cannot stretch, which a test now guarantees. The audit's most valuable finds were silent ones (logging to yesterday, a height saved a foot short): nothing crashes, the numbers are simply wrong, so both now have tests.

---

### Sprint 8 — Safer data, your own meals and workouts, and sync ✅

**Sprint goal:** make saved data hard to lose, then deliver the five items picked from the backlog: safer saving, journal mood trends with iCloud sync, favourite foods and saved meals, build-your-own workouts, and session sound with the screen locked.

| ID | Story | Acceptance criteria | Pts |
|----|-------|---------------------|-----|
| E9-1 | As a user, I never want a damaged file to cost me my logs. | A file that won't decode is moved aside, never deleted or left blocking saves; the app carries on from the copy saved at the last clean launch, or from nothing, and says which; lists decode entry by entry so one bad entry costs only itself; the set-aside file can be shared or deleted from Settings; a file that can't be read before first unlock is left alone and read again later; the profile has the same protection. | 8 |
| E9-2 | As a user, I want logging to stay instant however much I've logged. | Saving runs on a background writer; changes in quick succession become one write; nothing is left unsaved when the app leaves the screen; erase cancels anything waiting. | 5 |
| E9-3 | As a user, I want a breathing session to carry on when I lock my iPhone. | A playing sound continues with the screen locked and the clock keeps time; the session saves when it ends; a paused or silent session stops its clock and releases the audio hardware; time the app spent suspended is never counted. | 5 |
| E9-4 | As a user, I want to log what I usually eat quickly. | Any food can be starred from the meal logger or its nutrition sheet, and favourites list first; the foods in a meal can be saved under a name and logged again in one tap; an empty meal offers yesterday's; all of it is in the export. | 5 |
| E9-5 | As a user, I want to build my own workout. | Pick exercises from the library, any of them more than once; set time, or reps and sets, for each; reorder and remove; choose type and level; length and energy are worked out; the workout runs in the same player and can be edited or deleted; every library exercise has a demonstration. | 8 |
| E9-6 | As a user, I want to see how my mood moves over time. | Progress shows each day's mood on a low-to-great scale over 7 or 30 days, the moods chosen most often, and how the period compares with the one before; the Journal shows the last seven days at a glance; charts have spoken summaries and an Audio Graph. | 5 |
| E9-7 | As a user, I want my data on all my iPhones. | Off until turned on; logs, journal, favourites, saved meals and built workouts match across devices on one Apple Account; edits and deletions travel; two devices changing things at once lose nothing; "Erase all data" reaches the other devices; the iCloud copy can be deleted; no account, restricted accounts, lost connections and a copy from a newer version are each handled and explained; nothing read from Apple Health is synced. | 13 |

**How the sprint ran**

1. *Refinement.* Order was set by dependency: every feature saves through the same store, so E9-1 and E9-2 went first and the data model for the others (favourites, saved meals, built workouts, the change log) was designed with them.
2. *Decisions made up front.*
   - **Sync keeps one copy, not one record per entry.** A device fetches the copy, merges, and saves it back only if nothing changed in between. That needs one record type, no zones, subscriptions or push, and puts every rule in one pure function that can be tested with two simulated devices. The cost is that a change uploads the whole copy (compressed), and other devices see it when they are next opened rather than at once.
   - **The profile is not synced.** A second iPhone creates a fresh profile during setup, which would look newer than the real one and overwrite it. Syncing it safely needs a "restore from iCloud" step in onboarding: backlog.
   - **Mood has a scale.** To chart and compare days, each mood is placed from 1 (low) to 5 (great); several share a place. The card says where the numbers come from.
   - **Built workouts use the exercises that have demonstrations.** Three staples were added by reusing existing movements (Squat, Plank, Jog on the spot) rather than shipping exercises with no figure.
3. *Build.* One story at a time, each tested and pushed: storage, lock-screen sound, favourites and saved meals, workout builder, mood trends, sync.
4. *Review.* 160 unit tests and 7 UI tests, including the accessibility audits (now covering the workout builder, exercise picker and iCloud sync screen); a simulator walkthrough of each feature.

**Also fixed on the way:** workout cards in a row now line up at the top when one needs two lines for its level; the Library count includes workouts you built.

**Checked on the simulator:** a session's clock ran through 40 seconds of locked screen; favourites, "Same as yesterday" and saving a meal; building, saving and opening a workout; the Mood card and week strip; and the iCloud screen in a signed build, which reached CloudKit and reported "Not signed in to iCloud" as it should on a simulator with no account.

**Not verified, and why**

- **A real sync through iCloud.** The simulator has no iCloud account, so nothing was uploaded or downloaded for real. The merge rules and the fetch–merge–save loop are tested against a stand-in; the thin layer that talks to CloudKit is not. It needs two iPhones on one Apple Account (QA checklist in `docs/APP_STORE.md`).
- **Sound with the screen locked, by ear,** and what happens to a locked session when a call comes in.
- **Device signing with the iCloud capability.** The container has to be created once in Xcode (`docs/APP_STORE.md`, step 3a), and the schema deployed to Production before release (step 3b).

**Risks to decide before release**

- **App Review guideline 5.1.3** restricts keeping personal health information in iCloud. Sync is opt-in, covers only what the user typed in, and never includes anything read from HealthKit; the review notes say so. Whether that satisfies review is Apple's call; the fallback is described in `docs/APP_STORE.md`, section 4.
- **The audio background mode** is reviewed for apps that declare it; it is used only while a session's sound is audible.

**Retro:** putting the rules for sync in a pure function, and giving tests a stand-in for iCloud that refuses a stale save the way CloudKit does, meant the hard cases (a deletion that must not come back, two devices saving at once, an erase that has to reach a device that was offline) were settled before any CloudKit code existed. Splitting "can't read the bytes" from "can't decode them" mattered more than it looked: treating a locked phone's unreadable file as damaged would have replaced good data with an empty file.

---

### Sprint 9 — Accounts, a plan that follows you, GLP-1, Live Activities ✅

**Sprint goal:** five requests from device use: require an account (Apple, Google or email); a Live Activity for workouts and breathing; goals that drive the daily targets; fix iCloud sync failing on a real iPhone; and GLP-1 dose and side-effect tracking.

| ID | Story | Acceptance criteria | Pts |
|----|-------|---------------------|-----|
| E10-1 | As a user, I want iCloud sync to work, or tell me why it doesn't. | The failure on the iPhone is found from the phone's own log; each cause has its own message and advice; the technical detail is one tap away; a failed sync retries by itself and when the iCloud account changes. | 5 |
| E10-2 | As someone on a GLP-1 medicine, I want to track it. | Log a dose with medicine, amount, time and injection site; ten medicines listed with the strengths they are sold in, any other typed in; last dose and next-due shown; log side effects with strength and notes; edit and delete; exported and synced; no dose is ever suggested. | 8 |
| E10-3 | As a user, I want my targets to follow my goal and my body. | Targets for food energy, protein, Move, steps, exercise, water, sleep and mindful minutes come from focus, sex, age, height, weight and activity level; they change when any of those change; Today shows the figures the focus puts first; weight can be recorded and is charted; targets can still be set by hand; goals from before are untouched. | 13 |
| E10-4 | As a user, I want to see my session on the Lock Screen. | A workout or breathing session shows as a Live Activity on the Lock Screen and in the Dynamic Island with a clock that runs without the app; a breathing session says breathe in, hold or breathe out, with a ring that fills and empties; pausing, changing exercise and finishing update it; a session closed mid-way leaves nothing behind. | 8 |
| E10-5 | As the owner, I want everyone to have an account. | The app opens on sign-in; accounts are made with Sign in with Apple, Google or email and password; password reset; the session survives relaunch; sign out; delete account in the app; a second account on the same phone is asked before the first one's data is erased. | 13 |

**How the sprint ran**

1. *The bug first (E10-1).* The message on screen ("Couldn't reach iCloud") said nothing, so the first step was to read the phone's log. Three different errors turned up across launches: a server error, "account temporarily unavailable … failed to renew account credential", and finally "Invalid container to get bundle ids". None is in the sync logic: iCloud's servers did not yet recognise the container, which had been created that day. The fix was to stop hiding the cause: each case now has its own message, the full error is shown under *Details for support*, and the app retries on its own.
2. *Decisions made up front.*
   - **Accounts use Firebase Authentication, through its web API.** The project once used Firebase, it supports all three ways of signing in, and it is free at this size. Calling its REST API directly means no SDK in the app, and it sits behind a protocol so another service could replace it. Only the sign-in lives there: no logs go to the account.
   - **A development build works before Firebase is set up.** With no keys, Debug builds keep accounts on the device and say so on the sign-in screen; Release builds cannot sign anyone in.
   - **The plan is moderate on purpose.** Weight loss is at most a 500 kcal deficit with a floor of 1,200 to 1,500 kcal; nobody under 13 gets a plan; every screen says these are estimates, not medical advice.
   - **The GLP-1 tracker records and nothing more.** It lists the strengths medicines are sold in as shortcuts, and never suggests a dose or comments on a side effect beyond telling the user when to contact their prescriber.
   - **Workouts stay paused while the phone is locked.** The app is suspended then, so the Live Activity keeps the time but cannot move to the next exercise. Keeping workouts running in the background is in the backlog.
3. *Build.* One story at a time, each tested and pushed: sync, GLP-1, plan, Live Activity (then redesigned on request, to show the breath phase), accounts.
4. *Review.* 216 unit tests and 7 UI tests, including accessibility audits of sign-in and account creation; simulator walkthroughs of each feature; the sync diagnosis on the iPhone itself.

**Checked on the simulator:** the GLP-1 tracker end to end; the plan card and worked-out targets; the Live Activity on the Lock Screen changing from Hold to Breathe out while locked; creating an account with email and going through onboarding (UI test).

**Checked on the iPhone:** the sync errors, read from its log over several launches.

**Not verified, and why**

- **Real accounts.** There is no Firebase project yet, so no request has reached Firebase, Apple or Google. Requests and replies are tested against what those services document; the round trip is not. Needs `docs/APP_STORE.md` step 3c, then the QA checklist.
- **Revoking Apple access on deletion.** Written from Firebase's documented request; cannot be exercised without a real Apple-made account.
- **iCloud sync end to end.** Still blocked by the container not being recognised. If it has not cleared within a day, sign in to CloudKit Console and open the container, then check the Details shown on the sync screen.
- **Live Activity on a device:** how often iOS lets the breathing banner update over a long session, and the Dynamic Island views.

**After the sprint: accounts switched off for now.** The owner chose to hold off on Firebase, so sign-in is dormant: with no account service configured the app opens straight into onboarding and is used without an account, as before, and nothing about accounts shows in Settings, the policy or the terms. Everything built for E10-5 stays in place and is still tested; adding the Firebase keys turns it on and makes it required. The privacy manifest, policy page, support page and App Store answers are back to "no account, nothing collected", with the account versions kept in `docs/APP_STORE.md`, step 3c, to restore at the same moment. 218 unit tests and 8 UI tests pass, one of them walking the sign-in screens in test mode.

**Decisions waiting on the owner (they apply when accounts are switched on)**

- **App Review guideline 5.1.1(v).** Apps without significant account-based features are expected to work without signing in. With data kept on the device, the account currently does one thing: sign you in. Either give it a job (account-based backup is the natural one) or be ready for the question. See `docs/APP_STORE.md`, section 4.
- **The App Privacy label changes** from "Data Not Collected" to Email Address, Name and User ID.
- **Existing users will have to make an account** on their first launch after accounts go live; the data already on the phone passes to that account.

**Retro:** an error message that says "couldn't reach iCloud" for every failure cost a round trip with the owner; the log had the answer in one line. Errors now carry their cause to the screen. Describing the Live Activity as moments in time rather than values to redraw is what lets the ring and clocks keep moving with the app asleep, and made the breath phase a one-line update. The largest risk this sprint is not in the code: requiring an account changes what the app promises about privacy, and that needs an owner's decision before release.

---

## 7. Next backlog (1.1+)

Ordered within each group. *audit* marks findings from Sprint 7's code audit that were scheduled rather than fixed.

### Dependability (do first)

| Priority | Item |
|---|---|
| High | **Switch accounts on** (Firebase project and keys, privacy manifest, label, policy pages: `docs/APP_STORE.md`, step 3c), once the question below is settled. |
| High | **Give the account a job, or make it optional.** Back data up to the account (a server-side store per user, with the privacy label and policy to match), so signing in on a new phone brings everything back; this is also the answer to App Review guideline 5.1.1(v). |
| High | Keep each account's data separately on a shared iPhone, instead of asking to erase the last person's. |
| High | Tell the user when a save fails (storage full) instead of only logging it, and keep more than one saved copy to fall back on. |
| Medium | Entries that arrive, change or are deleted through iCloud sync are not mirrored to Apple Health on the receiving iPhone, on the assumption that Health's own iCloud sync carries them. Confirm on two devices that this leaves no duplicates and no leftovers after a delete. |
| Medium | *audit* — Writes to Apple Health are unordered, so add-then-delete can leave a sample behind. Send them through one queue. |
| Medium | *audit* — The same night can be logged twice, which doubles that day in Progress. Offer to replace an overlapping night; total sleep per day. |
| Medium | *audit* — Each screen re-filters the whole history many times per redraw. Compute each day's slice once and cache merged sleep and meals. |
| Low | *audit* — Today shows two different water and mindful figures when another app logged some (one tile counts Health, one doesn't). |
| Low | *audit* — Setup keeps typed numbers when units are switched (70 kg becomes 70 lb) and stores a made-up birthday on an optional screen. |
| Low | *audit* — Food imported from Health is grouped by exact time, so two foods logged in the same second merge. |
| Low | *audit* — Barcode lookup waits for USDA before trying Open Food Facts; ask both at once. |

### Features

| Priority | Item |
|---|---|
| High | **Filmed exercise clips.** License or film a short loop per exercise and add it to the app; the player already shows a clip named after the exercise in place of the drawn figure. Decide the source first (stock library licence, a trainer, or filming). |
| High | **Fuller restaurant coverage.** USDA has no Starbucks, Chipotle, Dunkin', Panera, Five Guys or Panda Express, and its restaurant figures are years old. A commercial menu database (Nutritionix, FatSecret) covers them, with a monthly cost, a key to protect, and a privacy-label update. |
| High | **Sync the profile and restore on a new iPhone.** Offer "Restore from iCloud" during setup so a new device takes the existing profile, goals and photo instead of creating a fresh one; then sync later changes. |
| High | **Sync as it happens.** A CloudKit subscription and silent push, so a change shows on other devices within seconds rather than when they are next opened. Needs the push entitlement and remote-notification background mode. |
| Medium | Sync per entry rather than one copy, once histories grow large enough for the whole-copy upload to matter (measure first). |
| Medium | An optional journal reminder; show a day's mood on Today |
| Medium | Rename and reorder saved meals and favourites; save a meal straight from a logged meal's menu |
| Medium | More exercises with demonstrations for the workout builder; rest between sets in the player; a spoken or haptic cue when the exercise changes; duplicate a library workout to edit it |
| Medium | Lock-screen controls for a session (pause and resume, title, time left) |
| High | **Keep workouts running with the phone locked** (a HealthKit workout session), so timed exercises move on by themselves and the Live Activity follows; add a sound or haptic at each change. |
| Medium | GLP-1: a reminder when the next dose is due; a chart of dose over time beside weight; injection-site rotation at a glance; a summary to share with a prescriber. |
| Medium | Plan: save weight to Apple Health and read it from there; a weekly check-in that adjusts the plan to the trend; let food energy flex with the day's activity. |
| Medium | Accounts: verify the email address; change email or password in the app; link Apple and Google to one account. |
| Medium | Live Activity: pause and resume from the Lock Screen (App Intents). |
| Medium | Save journal moods to Apple Health as State of Mind (iOS 18+), with the user's permission |
| Medium | Home Screen widgets and App Intents ("Log 250 ml of water") |
| Medium | A weekly summary: what went well, in plain words |
| Medium | iPad layout |
| Medium | Localization (String Catalog) |
| Low | Apple Watch companion for workouts and breathing |

### Experience and accessibility

| Priority | Item |
|---|---|
| Medium | *audit* — Selected chips (focus, sleep quality, theme, filters) differ mainly by colour; add a checkmark or weight change. |
| Medium | *audit* — The breathing player can't grow with the largest text sizes on small phones; let its middle scroll. |
| Low | *audit* — "Type the number instead" on the barcode scanner is under 44 pt tall on iOS 17–25. |
| Low | *audit* — Food details and Edit profile show Done/Cancel beside a Back button when pushed rather than presented. |
| Low | *audit* — Tidy-up: unused design-system pieces, three copies of the progress bar, four of the Today/Yesterday label, three chip types. |
