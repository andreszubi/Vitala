# Vitala 1.0 — App Store Submission Kit

Everything needed to submit Vitala, in the order you'll need it. Items marked **You** need your Apple Developer account and can't be done from the code.

---

## 1. Before you archive (You)

0. **Add your USDA FoodData Central key** (free from https://fdc.nal.usda.gov/api-key-signup). Open `Config/Secrets.xcconfig` (Git ignores it) and paste the key after `USDA_API_KEY =`. Without a key, Release builds hide online food search; Debug builds use USDA's shared, heavily rate-limited `DEMO_KEY`. A key allows 1,000 requests per hour per key across all users; if Vitala grows past that, request a higher limit from api.data.gov or route searches through a small proxy.

1. **Join the Apple Developer Program** (paid membership is required for HealthKit and App Store distribution).
2. **Choose the bundle ID.** The project uses `com.vitala.healthyliving`. If that's taken or you prefer your own domain (for example `com.andreszubizarreta.vitala`), change `PRODUCT_BUNDLE_IDENTIFIER` for the Vitala target (and the two test targets' `.tests` / `.uitests` suffixes).
3. In Xcode → Vitala target → **Signing & Capabilities**: pick your **Team**, for both the **Vitala** and **VitalaWidgetsExtension** targets. Xcode registers the bundle IDs and enables the **HealthKit**, **iCloud** and **Sign in with Apple** capabilities from `Vitala.entitlements` (Sign in with Apple is there for when accounts are switched on; it does nothing until then).
3a. **Create the iCloud container (once).** Still in Signing & Capabilities, the **iCloud** section should show **CloudKit** ticked and a container named `iCloud.` followed by the bundle ID (`iCloud.com.vitala.healthyliving`). If the container is listed in red or missing, press the refresh arrow, or **+** and enter that exact name, so Xcode creates it. Until it exists, builds for a real iPhone fail to sign. If you change the bundle ID, the container name follows it automatically.
3b. **Deploy the CloudKit schema to Production before submitting.** Run a build from Xcode on your iPhone, turn on **Settings › iCloud sync** and log something, so the record type `VitalaData` is created in the Development environment. Then open [CloudKit Console](https://icloud.developer.apple.com) → the container → **Deploy Schema Changes…** and deploy to Production. TestFlight and App Store builds use Production: without this step, sync fails for every user while working for you in Xcode.
3c. **Accounts are built but switched off.** With no Firebase key, Vitala opens straight into onboarding and is used without an account, exactly as before; nothing about accounts shows anywhere. Adding the key turns sign-in on and makes it required. Do all of the following together, when you are ready:
   1. In the [Firebase console](https://console.firebase.google.com), create a project (no Analytics needed) and add an **iOS app** with the bundle ID `com.vitala.healthyliving`.
   2. **Build › Authentication › Sign-in method**: enable **Email/Password**, **Google** and **Apple**.
   3. Download `GoogleService-Info.plist` from the app's settings. Do not add it to the project. Copy two values from it into `Config/Secrets.xcconfig` (Git ignores that file): `API_KEY` after `FIREBASE_API_KEY =` and `CLIENT_ID` after `GOOGLE_CLIENT_ID =`. From the next build, the app opens on the sign-in screen.
   4. In the [Google Cloud console](https://console.cloud.google.com/apis/credentials), open the API key and restrict it to **iOS apps** with your bundle ID, and to the **Identity Toolkit API** and **Token Service API**.
   5. Run on your iPhone and check all three ways of signing in, password reset, sign out, and deleting an account made each way (QA checklist, section 7).
   6. **Declare what accounts collect.** In `Vitala/Resources/PrivacyInfo.xcprivacy`, replace the empty `NSPrivacyCollectedDataTypes` array with entries for the email address, name and user id:

   ```xml
   <key>NSPrivacyCollectedDataTypes</key>
   <array>
   	<dict>
   		<key>NSPrivacyCollectedDataType</key>
   		<string>NSPrivacyCollectedDataTypeEmailAddress</string>
   		<key>NSPrivacyCollectedDataTypeLinked</key>
   		<true/>
   		<key>NSPrivacyCollectedDataTypeTracking</key>
   		<false/>
   		<key>NSPrivacyCollectedDataTypePurposes</key>
   		<array>
   			<string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
   		</array>
   	</dict>
   	<!-- and the same again for NSPrivacyCollectedDataTypeName
   	     and NSPrivacyCollectedDataTypeUserID -->
   </array>
   ```

   7. **Change the App Privacy label** to the three types in section 4, and give App Review a sign-in (section 5).
   8. **Publish the account sections** of the privacy policy and support page. The app's own copy of the policy and terms adds its account paragraphs by itself once the key is set; the web pages do not. Add this to `docs/privacy-policy.md` after "What Vitala stores", and change "Vitala has no account system and no servers of its own" to "Vitala has no servers of its own":

   ````markdown
   ## Your account

   Vitala needs an account. You can create one with **Sign in with Apple**, with **Google**, or with an **email address and a password**.

   Accounts are kept by [Firebase Authentication](https://firebase.google.com/support/privacy), a service of Google. It stores:

   - your email address, or the private relay address Apple gives you if you choose to hide it;
   - the name Apple or Google shares, if any;
   - an account identifier;
   - for email accounts, a protected form of your password that cannot be read back.

   **Nothing you log in Vitala is stored with your account**: no meals, workouts, sleep, weight, medicines, side effects, journal entries or Apple Health data. The account is used only to sign you in. It is not used for advertising or tracking.

   You can delete your account at any time in **Settings › Account › Delete account**. That removes the account from Firebase and erases your data from your iPhone.
   ````

      and replace the "Do I need an account?" answer in `docs/support.md` with:

   ````markdown
   ## Do I need an account?

   Yes. When you first open Vitala, create an account with **Sign in with Apple**, **Google**, or an **email address and password**. The account holds only your sign-in; everything you log stays on your iPhone (and in your own iCloud, if you turn sync on).

   ## I forgot my password

   On the sign-in screen tap **Continue with email**, choose **Sign in**, type your email address and tap **Forgot your password?** A link to choose a new one is sent to that address. If you signed up with Apple or Google there is no password: use the same button you used before.

   ## How do I sign out or delete my account?

   Tap your avatar, then **Settings › Account**. **Sign out** leaves your data on the iPhone for when you sign back in. **Delete account** removes your Vitala account and erases your profile and logs from the iPhone; it can't be undone. If your account was made with Apple, Apple asks you to confirm it's you first.

   If someone else signs in on your iPhone, Vitala asks before it erases your data to make room for theirs.
   ````

   To try the sign-in screens before any of this, add the launch argument `-requireSignIn` to a Debug run: accounts are then kept on the device and nothing is checked.
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

> Water, meals, movement, sleep, breathing and journaling in one calm daily rhythm, with targets made for you. What you log stays on your iPhone, or in your own iCloud.

### Description

> Vitala is a gentle companion for everyday wellness. Log a glass of water, a meal, a walk or last night's sleep in seconds, and watch small habits add up.
>
> TODAY AT A GLANCE
> • Move, Exercise and Steps rings with your own goals
> • One-tap logging for water, meals, mindful minutes and sleep
> • Streaks and weekly workout progress that reflect what you actually did
>
> A PLAN MADE FOR YOU
> • Tell Vitala your goal — lose weight, build muscle, sleep better, manage stress or stay balanced — and it works out your daily targets from your height, weight, age and how active you are
> • Food energy, protein, steps, active energy, water and sleep targets that update when your weight or goal changes
> • Record your weight and watch it move towards your target
>
> MOVE
> • Guided sessions — yoga, strength, HIIT, mobility and running — with timers that count down each exercise
> • An animated demonstration of every exercise, so you can see how it's done
> • Build your own workout from the exercise library: choose the exercises, then the time or reps for each
> • See your workout on the Lock Screen and in the Dynamic Island
> • Log any activity with type, duration, energy and distance
>
> EAT WELL
> • Search hundreds of thousands of foods with real portions, or scan a barcode to log packaged food
> • Find meals from popular restaurant chains and log them by the item
> • Log breakfast, lunch, dinner and snacks, with custom and recent foods that work offline
> • Star the foods you eat most, save a whole meal to log again in one tap, or repeat yesterday's
> • See calories, protein, carbs and fat against a target suggested from your profile
> • Track fiber, sugar, saturated and unsaturated fat and sodium, and tap any food or meal for its full nutrition
> • Taking a GLP-1 medicine? Log each dose, see when the next is due, and note any side effects
>
> BREATHE
> • Nine guided breathing sessions for focus, stress, sleep and gratitude, each with its own rhythm and calming cues
> • Spa sound, crystal singing bowls, ocean waves and optional binaural tones, generated live on your iPhone
> • Peaceful animated scenes — ocean at dusk, rain on water, starry night, misty mountains, aurora
> • Gentle haptics you can feel building as you breathe in and easing as you breathe out
> • Lock your iPhone and the sound carries on until the session ends
> • A Live Activity on your Lock Screen tells you when to breathe in, hold and breathe out
>
> REFLECT
> • Keep a private mood journal: pick how you feel, write whatever's on your mind
> • Journal right after a breathing session, or any time; look back day by day
> • See your mood over the week and the month, and which moods come up most
>
> SLEEP
> • Log bedtime, wake time and how it felt, or let nights from Apple Watch and the iPhone sleep schedule fill in automatically
> • Track your 7-night trend against your goal
>
> PROGRESS
> • 7- and 30-day trends for steps, exercise, food, water, sleep and mindful minutes
> • A 28-day consistency view of every day you showed up
>
> WORKS WITH APPLE HEALTH
> Connect Apple Health to see steps, heart rate, sleep and food from your other apps in Vitala, and to save the water, sleep, mindful sessions and workouts you log back to Health. Health is optional — Vitala works fully without it.
>
> ON ALL YOUR IPHONES, IF YOU WANT
> Turn on iCloud sync and your logs, journal, favourite foods, saved meals and workouts match on every iPhone you sign in to. It is off until you choose it, and uses your own private iCloud.
>
> PRIVATE BY DESIGN
> No account. No servers of ours. No ads or tracking. Everything stays on your iPhone, or in your own iCloud if you turn sync on, and you can export or erase it any time.
>
> ACCESSIBLE
> Dynamic Type, VoiceOver with spoken chart summaries, Reduce Motion and high-contrast colours throughout.
>
> Vitala is a wellness companion, not a medical device. Talk to a healthcare professional about medical questions.

### Keywords (≤100 characters)

```
wellness,habit,water,hydration,sleep,meditation,breathing,calorie,fitness,mindfulness,mood,journal
```

## 4. App Privacy ("nutrition label")

Recommended answer for now: **"No, we do not collect data from this app."**

Why: "collect" means data sent off the device in a way that you or a partner can access. Everything the user logs stays on the device, in their own Apple Health and, with sync on, in their own iCloud. The app has no analytics, ads or third-party SDKs, and while accounts are switched off nobody signs in. The privacy manifest (`Vitala/Resources/PrivacyInfo.xcprivacy`) declares no tracking, no collected data types, and the one required-reason API (UserDefaults, reason CA92.1).

**Once accounts are switched on (step 3c), this answer changes.** Declare exactly these three types, each **linked to the user**, **not used for tracking**, purpose **App Functionality**:

| Category | Type | Why |
|---|---|---|
| Contact Info | Email Address | The address the account is made with (or Apple's private relay address) |
| Contact Info | Name | The name Apple or Google shares at sign-in, if any |
| Identifiers | User ID | The account's id |

They are held by Firebase Authentication (Google), which acts for you as a processor.

**Do not declare Health & Fitness or Sensitive Info** on the strength of the GLP-1 tracker, weights or logs: they are not collected. If you later move any of it to a server, this changes.

**iCloud sync does not change this answer.** With sync on, a copy of the user's logs goes to the private database of *their own* iCloud account through CloudKit. Neither you nor any third party can read a private CloudKit database, so by Apple's definition the data is not "collected". The privacy policy discloses it, and sync is off until the user turns it on.

**Before switching accounts on, read guideline 5.1.1(v).** It says an app without significant account-based features should let people use it without signing in. With all data kept on the device, a required account would do one thing, sign you in, so a reviewer may ask what it is for. Decide your answer first: either give the account a job (for example, backing up data to it, which is in the backlog) or make sign-in optional. The same guideline requires that accounts can be deleted in the app, which Settings › Account does; and guideline 4.8 requires Sign in with Apple alongside Google, which is there. None of this applies while accounts are off.

**Read guideline 5.1.3 before submitting.** It restricts keeping personal health information in iCloud. Vitala's position: sync is opt-in; it covers only what the user typed into Vitala; nothing read from HealthKit is ever stored or synced (steps, heart rate and imported sleep and food are read live and never saved); and the profile with height and weight is not synced at all. The review notes below say so. If App Review objects, the fallback is to keep favourite foods, saved meals and built workouts in sync and take the logs and journal out of it, which is a contained change in `SyncMerge`.

**Food search and barcode lookups are the one judgement call.** The typed search words (e.g. "banana") or a scanned barcode number go to USDA FoodData Central (and, for barcodes not found there, Open Food Facts), with no identifiers, only to answer that lookup. That fits "processed in real time to serve the request", so "Data Not Collected" stays defensible. If you'd rather be maximally cautious, declare **Search History → App Functionality → Not linked to the user → Not used for tracking** instead. Either way the privacy policy already discloses it, and users can switch it off in Settings › Food search.

## 5. Notes for App Review

Paste into **App Review Information › Notes**:

> Vitala does not require an account or sign-in; all features are available immediately after onboarding (enter any first name).
>
> Goals: daily targets are general estimates worked out from the user's stated goal, sex, age, height, weight and activity level (Mifflin–St Jeor energy equation). For weight loss the deficit is capped at 500 kcal a day with a minimum intake of 1,200 to 1,500 kcal. The app says these are not medical advice and that users should talk to a healthcare professional.
>
> GLP-1 tracker (Nutrition › GLP-1 tracker): a personal log of doses the user says they took and side effects they noticed. It does not recommend, prescribe or calculate doses, and gives no treatment advice. Medicine names appear only so a dose can be logged under the name on the box; Vitala has no affiliation with their makers. The listed strengths are the ones the medicines are sold in, offered as shortcuts; any amount can be typed instead.
>
> Live Activity: a workout or breathing session in progress is shown on the Lock Screen and in the Dynamic Island. It ends when the session ends.
>
> HealthKit: Vitala reads steps, active energy, exercise minutes, walking/running distance, heart rate, sleep analysis, mindful minutes, and dietary energy, protein, carbohydrates and fat recorded by other apps to show daily progress and history, and writes dietary water, sleep analysis, mindful sessions and workouts that the user logs in the app. HealthKit is optional; the Connect button is on the Today screen and in Profile › Apple Health. HealthKit data is never shared, sold or used for advertising, and never leaves the device through Vitala.
>
> Mindfulness sessions play ambient sound and animated scenes generated on the device, with optional haptic guidance; no audio, video or third-party content is included. Journal entries (a mood and free text) are stored only on the device and are not written to HealthKit.
>
> Background audio: a breathing session's ambient sound is generated on the device and keeps playing when the user locks the screen, until the session ends or is paused. This is the only use of the audio background mode; a paused or silent session releases the audio session.
>
> iCloud sync (optional, off by default; Settings › iCloud sync): when the user turns it on, the entries they logged in Vitala are stored in the private CloudKit database of their own iCloud account so their other devices can show them. No data read from HealthKit is stored or synced, and the developer has no access to the private database. The user can delete the iCloud copy from the same screen.
>
> Notifications are optional daily reminders the user configures in Settings › Reminders.
>
> Food search and barcodes: when the user searches for a food, the typed words are sent to USDA FoodData Central (api.nal.usda.gov), a public U.S. government nutrition database. When the user scans or types a barcode, the number is sent to USDA FoodData Central and, if not found, to Open Food Facts (openfoodfacts.org). No user identifiers are sent; online lookups can be turned off in Settings › Food search.
>
> Restaurant foods: nutrition for restaurant items comes from the same USDA database, which publishes it as public data. Chain names appear only as labels saying where a food is from; Vitala has no affiliation with them and the listing does not name them.
>
> Camera: used only in Log a meal › Scan barcode to read product barcodes with VisionKit. Nothing is recorded. On the simulator or without camera access, the scanner offers manual number entry. Test barcode: 016459200441.

No demo account is needed while accounts are off.

**Once accounts are switched on (step 3c):** replace the first paragraph of the notes with the one below, create an email account in the app for App Review, complete onboarding with it, and enter its email and password under **App Review Information › Sign-In Information**. Keep that account alive while the app is in review.

> Sign-in: Vitala requires an account, made with Sign in with Apple, Google, or an email address and password. A reviewer account is provided; you can also create one in the app with any email address. Accounts hold only the sign-in details (Firebase Authentication); nothing the user logs is stored with the account. An account can be deleted in the app: avatar › Settings › Account › Delete account, which also erases the user's data from the device. After signing in, onboarding asks for a first name.

## 6. Screenshots

6.9-inch iPhone set (1320 × 2868), captured from seeded sample data in `docs/app-store/screenshots/`:

1. `01-Today.png` — rings, quick log, today's activity
2. `02-Activity.png` — sessions and the workout library
3. `03-Nutrition.png` — intake ring, macros and the More nutrients card
4. `04-Sleep.png` — latest night, 7-night chart
5. `05-Breathing.png` — guided breathing over the Ocean at dusk scene
6. `06-Progress.png` — consistency and trends
7. `07-Journal.png` — a mood journal entry

Suggested upload order: Today, Activity, Nutrition, Sleep, Breathing, Journal, Progress (the order of `screenshots-overview.png`).

Regenerate after UI changes:

```bash
TEST_RUNNER_VITALA_SCREENSHOTS=1 TEST_RUNNER_VITALA_SCREENSHOT_DIR="$PWD/docs/app-store/screenshots" \
xcodebuild test -project Vitala.xcodeproj -scheme Vitala \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
  -only-testing:VitalaUITests/ScreenshotTests
```

Set a clean status bar first with `xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100`.

## 7. Device QA checklist (TestFlight)

- [ ] Fresh install → onboarding → profile setup → Today, with no crashes (no sign-in screen while accounts are off)
- [ ] *Once accounts are on:* fresh install opens on the sign-in screen; create an account → onboarding → profile setup → Today
- [ ] *Once accounts are on:* sign in with Apple (once sharing the email, once hiding it), with Google, and with email; a wrong password is refused with a clear message; Forgot your password sends an email that works; quit and reopen stays signed in; Sign out returns to sign-in and signing back in shows the same data
- [ ] *Once accounts are on:* delete an account made each of the three ways (Apple asks to confirm first); afterwards the account can't sign in, the data is gone from the iPhone, and for Apple the app no longer appears under Settings › your name › Sign in with Apple
- [ ] *Once accounts are on:* an iPhone that already has data from before accounts keeps it for the first account to sign in; sign in as a second account on the same iPhone and check Vitala asks before erasing the first account's data, and that Sign out leaves it untouched
- [ ] Plan: with height, weight and birthday set, Goals shows worked-out targets; changing focus or updating weight on Today changes them; turning "Work out my targets for me" off brings back the sliders and keeps the numbers
- [ ] GLP-1 tracker: log a weekly and a daily medicine, a typed amount, and a medicine under Other; the next-due line reads right the day before, on the day and the day after; log, edit and delete a side-effect note
- [ ] Live Activity, breathing: start a session with sound, lock the iPhone; the banner reads Breathe in, Hold and Breathe out in step with the session for several minutes, the time left counts down, and it says Session saved at the end. Check the Dynamic Island compact and expanded views
- [ ] Live Activity, workout: the banner shows the exercise, its place in the workout and the running time; it follows Next, Pause and Finish; force-quit mid-workout and reopen: the banner is gone
- [ ] Apple Health: Connect shows the permission sheet (including nutrition); steps and heart rate appear; a logged water entry, sleep entry, mindful session and workout appear in the Health app; editing one replaces it and deleting removes it
- [ ] Apple Health import: Apple Watch or sleep-schedule nights appear in Sleep, and food from another app appears in Nutrition, marked "Apple Health" and not editable; a night logged in Vitala replaces the overlapping Health night
- [ ] Journal: write an entry from the Mindfulness header, choose a mood, save, edit and delete it; finish a session and use Write in journal from the completion screen
- [ ] Reminders: allow notifications, set a time a minute ahead, receive it; turn it off and confirm nothing arrives
- [ ] Breathing session: sound starts on Spa, binaural & bowls, follows the breath, pauses with the session, works with AirPods; switching sounds takes one tap and crossfades with no click or skip; Silent stops it
- [ ] Breathing session: plug in or remove headphones mid-session and the sound carries on; leave the app for a minute and the timer has not moved on return; Pause then Restart brings the sound back
- [ ] Restaurants: in Log a meal, tap a chain under the search field; its menu lists; open an item and the portion reads as one item, not 100 g
- [ ] Workouts: each exercise shows a demonstration in the list and the player; it pauses with the workout; with music playing from another app, starting a workout does not stop it
- [ ] Breathing session: opens on the scene matching its kind; haptics build on the in-breath, ease on the out-breath, stop on pause and can be switched off; cues change every 20 seconds and differ between sessions
- [ ] Nutrition: a scanned product shows its full name and brand; tapping a food shows its nutrition; tapping Breakfast/Lunch/Dinner/Snack shows that meal's totals
- [ ] Breathing session with the screen locked: start a session with sound, lock the iPhone; the sound carries on, and on unlocking the timer has kept pace. Let one finish while locked: the sound fades and the session is saved. Pause, then lock: nothing plays and the timer has not moved on return. Take a phone call mid-session with the screen locked and check what the timer shows afterwards
- [ ] Favourites and saved meals: star a food and it leads the list next time; save a meal, log it again in one tap; "Same as yesterday" appears on an empty meal and adds yesterday's foods
- [ ] Build a workout: add exercises (one of them twice), set time on one and reps on another, reorder, save; it runs in the player, and Edit and Delete work
- [ ] Mood: the Journal's week strip shows the right mood under each day; Progress › Mood matches the entries at 7 and 30 days
- [ ] iCloud sync: turn it on and confirm Status reads "Up to date" (a brand-new iCloud container can take up to a day before iCloud accepts it; until then the screen says so and keeps retrying)
- [ ] iCloud sync, two iPhones on one Apple Account: turn it on on both; an entry logged on one appears on the other after opening it; an edit and a delete travel too; log on both while one is in Airplane Mode, reconnect, and both end up with everything
- [ ] iCloud sync: signed out of iCloud, the screen says so and nothing is lost; Erase all data with sync on clears the other iPhone's logs after it next opens; Delete the iCloud copy turns sync off and leaves the iPhone's data
- [ ] Damaged data: not testable by hand without tampering with the app's files; covered by unit tests
- [ ] Profile photo: add, change and remove
- [ ] Export my data produces a readable JSON file; Erase all data returns to onboarding
- [ ] VoiceOver walkthrough of every tab; Larger Text at the largest size; Dark Mode; Reduce Motion
- [ ] App icon looks right on the Home Screen in Light, Dark, Clear and Tinted

## 8. After approval

- Tag the release: `git tag v1.0.0 && git push --tags`
- Watch Xcode Organizer for crashes and App Store Connect for reviews.
