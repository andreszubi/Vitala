# Vitala 1.0 — App Store Submission Kit

Everything needed to submit Vitala, in the order you'll need it. Items marked **You** need your Apple Developer account and can't be done from the code.

---

## 1. Before you archive (You)

0. **Add your USDA FoodData Central key** (free from https://fdc.nal.usda.gov/api-key-signup). Open `Config/Secrets.xcconfig` (Git ignores it) and paste the key after `USDA_API_KEY =`. Without a key, Release builds hide online food search; Debug builds use USDA's shared, heavily rate-limited `DEMO_KEY`. A key allows 1,000 requests per hour per key across all users; if Vitala grows past that, request a higher limit from api.data.gov or route searches through a small proxy.

1. **Join the Apple Developer Program** (paid membership is required for HealthKit and App Store distribution).
2. **Choose the bundle ID.** The project uses `com.vitala.healthyliving`. If that's taken or you prefer your own domain (for example `com.andreszubizarreta.vitala`), change `PRODUCT_BUNDLE_IDENTIFIER` for the Vitala target (and the two test targets' `.tests` / `.uitests` suffixes).
3. In Xcode → Vitala target → **Signing & Capabilities**: pick your **Team**. Xcode registers the bundle ID and enables the **HealthKit** capability from `Vitala.entitlements`.
4. **Publish the privacy policy and support pages.** In GitHub → repository **Settings › Pages**, deploy from the `main` branch, `/docs` folder. The pages then live at:
   - `https://andreszubi.github.io/Vitala/privacy-policy`
   - `https://andreszubi.github.io/Vitala/support`

   These URLs are already used in the app (`AppInfo.swift`). GitHub Pages needs a public repository on the free plan; if you host elsewhere, update `AppInfo.privacyPolicyURL` and `AppInfo.supportURL`.
5. **Test on a real iPhone via TestFlight** — the simulator can't fully exercise Apple Health permissions, notifications, or audio routing to headphones. See the QA checklist in section 7.

## 2. Archive and upload (You)

1. Select **Any iOS Device (arm64)** as the destination.
2. **Product › Archive**, then **Distribute App › App Store Connect › Upload**.
3. Versioning lives in build settings: `MARKETING_VERSION` = 1.0.0, `CURRENT_PROJECT_VERSION` = 1. Bump the build number for every upload.
4. Export compliance is pre-answered (`ITSAppUsesNonExemptEncryption = NO`) — Vitala uses no custom encryption.

## 3. App information

| Field | Value |
|---|---|
| Name | Vitala |
| Subtitle (≤30) | Calm habits, gently tracked |
| Primary category | Health & Fitness |
| Secondary category | Lifestyle |
| Age rating | Expected 4+. Answer the questionnaire honestly: no objectionable content; if asked about health or wellness topics, answer Yes (Apple calculates the rating) |
| Price | Free |
| Availability | All territories (your choice) |
| Privacy Policy URL | https://andreszubi.github.io/Vitala/privacy-policy |
| Support URL | https://andreszubi.github.io/Vitala/support |
| Copyright | © 2026 Andres Zubizarreta |

### Promotional text (≤170)

> Water, meals, movement, sleep and breathing in one calm daily rhythm. Private by design — everything stays on your iPhone.

### Description

> Vitala is a gentle companion for everyday wellness. Log a glass of water, a meal, a walk or last night's sleep in seconds, and watch small habits add up.
>
> TODAY AT A GLANCE
> • Move, Exercise and Steps rings with your own goals
> • One-tap logging for water, meals, mindful minutes and sleep
> • Streaks and weekly workout progress that reflect what you actually did
>
> MOVE
> • Guided sessions — yoga, strength, HIIT, mobility and running — with timers that count down each exercise
> • Log any activity with type, duration, energy and distance
>
> EAT WELL
> • Log breakfast, lunch, dinner and snacks from a food list or your own custom foods
> • See calories, protein, carbs and fat against a target suggested from your profile
>
> BREATHE
> • Nine guided breathing sessions for focus, stress, sleep and gratitude, each with its own rhythm
> • Calming spa sound, ocean waves and optional binaural tones, generated live on your iPhone
>
> SLEEP
> • Log bedtime, wake time and how it felt; track your 7-night trend against your goal
>
> PROGRESS
> • 7- and 30-day trends for steps, exercise, food, water, sleep and mindful minutes
> • A 28-day consistency view of every day you showed up
>
> WORKS WITH APPLE HEALTH
> Connect Apple Health to see steps, heart rate and sleep in Vitala, and to save the water, sleep, mindful sessions and workouts you log back to Health. Health is optional — Vitala works fully without it.
>
> PRIVATE BY DESIGN
> No account. No servers. No ads or tracking. Everything stays on your iPhone, and you can export or erase it any time.
>
> ACCESSIBLE
> Dynamic Type, VoiceOver with spoken chart summaries, Reduce Motion and high-contrast colours throughout.
>
> Vitala is a wellness companion, not a medical device. Talk to a healthcare professional about medical questions.

### Keywords (≤100 characters)

```
wellness,habit,water,hydration,sleep,meditation,breathing,calorie,fitness,mindfulness,health,journal
```

## 4. App Privacy ("nutrition label")

Recommended answer: **"No, we do not collect data from this app."**

Why: "collect" means data transmitted off the device in a way that you or third-party partners can access beyond serving the request in real time. Vitala has no servers, analytics, ads or third-party SDKs; logs stay on the device and in the user's own Apple Health. The privacy manifest (`Vitala/Resources/PrivacyInfo.xcprivacy`) declares no tracking and no collected data types, and the one required-reason API (UserDefaults, reason CA92.1).

**Food search is the one judgement call.** The typed search words (e.g. "banana") go to USDA FoodData Central, a public government API, with no identifiers, only to answer that search. That fits "processed in real time to serve the request", so "Data Not Collected" stays defensible. If you'd rather be maximally cautious, declare **Search History → App Functionality → Not linked to the user → Not used for tracking** instead. Either way the privacy policy already discloses it, and users can switch it off in Settings › Food search.

## 5. Notes for App Review

Paste into **App Review Information › Notes**:

> Vitala does not require an account or sign-in; all features are available immediately after onboarding (enter any first name).
>
> HealthKit: Vitala reads steps, active energy, exercise minutes, walking/running distance, heart rate, sleep analysis and mindful minutes to show daily progress, and writes dietary water, sleep analysis, mindful sessions and workouts that the user logs in the app. HealthKit is optional; the Connect button is on the Today screen and in Profile › Apple Health. HealthKit data is never shared, sold or used for advertising, and never leaves the device through Vitala.
>
> Mindfulness sessions play ambient sound synthesised on the device; no audio files or third-party content are included.
>
> Notifications are optional daily reminders the user configures in Settings › Reminders.
>
> Food search: when the user searches for a food, the typed words are sent to USDA FoodData Central (api.nal.usda.gov), a public U.S. government nutrition database, to look up nutrition facts. No user identifiers are sent; this can be turned off in Settings › Food search.

No demo account is needed.

## 6. Screenshots

6.9-inch iPhone set (1320 × 2868), captured from seeded sample data in `docs/app-store/screenshots/`:

1. `01-Today.png` — rings, quick log, today's activity
2. `02-Activity.png` — sessions and the workout library
3. `03-Nutrition.png` — intake ring, macros, meals
4. `04-Sleep.png` — latest night, 7-night chart
5. `05-Breathing.png` — guided breathing with sound
6. `06-Progress.png` — consistency and trends

Regenerate after UI changes:

```bash
TEST_RUNNER_VITALA_SCREENSHOTS=1 TEST_RUNNER_VITALA_SCREENSHOT_DIR="$PWD/docs/app-store/screenshots" \
xcodebuild test -project Vitala.xcodeproj -scheme Vitala \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
  -only-testing:VitalaUITests/ScreenshotTests
```

Set a clean status bar first with `xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100`.

## 7. Device QA checklist (TestFlight)

- [ ] Fresh install → onboarding → profile setup → Today, with no crashes
- [ ] Apple Health: Connect shows the permission sheet; steps and heart rate appear; a logged water entry, sleep entry, mindful session and workout appear in the Health app; editing one replaces it and deleting removes it
- [ ] Reminders: allow notifications, set a time a minute ahead, receive it; turn it off and confirm nothing arrives
- [ ] Breathing session: sound starts, follows the breath, pauses with the session, works with AirPods; switching to Silent stops it
- [ ] Profile photo: add, change and remove
- [ ] Export my data produces a readable JSON file; Erase all data returns to onboarding
- [ ] VoiceOver walkthrough of every tab; Larger Text at the largest size; Dark Mode; Reduce Motion
- [ ] App icon looks right on the Home Screen in Light, Dark, Clear and Tinted

## 8. After approval

- Tag the release: `git tag v1.0.0 && git push --tags`
- Watch Xcode Organizer for crashes and App Store Connect for reviews.
