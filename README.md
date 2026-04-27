# Vitala — Healthy Living App (Class Demo Build)

A SwiftUI iOS 17+ app: onboarding, profile setup, dashboard with Activity rings, workouts, nutrition, water, sleep, mindfulness, progress, and settings.

**This build is in demo mode** — no Firebase, no auth screen. The app launches a local demo user automatically, persists everything to `UserDefaults`, and goes straight from the onboarding into the main experience. Everything else (HealthKit, charts, the full screen flow) works normally. See **[Re-enabling Firebase](#re-enabling-firebase-optional)** at the bottom if you want to flip auth + cloud sync back on later.

## What's inside

```
Vitala/
├── Vitala.xcodeproj/        # Generated — open this
├── Vitala/
│   ├── App/                 # VitalaApp, RootView, MainTabView
│   ├── DesignSystem/        # Colors, Typography, Spacing, Components
│   ├── Models/              # User, Workout, Meal, Water, Sleep, Mindfulness
│   ├── Services/            # AuthService, FirestoreService, HealthKitService, NotificationService
│   ├── ViewModels/          # AppState (root navigation)
│   ├── Features/            # 19 screens grouped by feature
│   └── Resources/           # Info.plist, Vitala.entitlements, Assets.xcassets, GoogleService-Info.plist
├── project.yml              # XcodeGen spec (optional regeneration)
├── scripts/generate_pbxproj.py   # Project regenerator
└── README.md
```

## Screens (19)

Splash → Onboarding (3 pages) → Sign in / Sign up / Forgot password → Profile setup (Personal info, Goals + focus, Permissions, Review) → Main app:
- **Dashboard** — Activity rings, quick stats, quick log shortcuts, streaks
- **Activity** — Workouts list with filters, detail, active workout timer with HK logging
- **Nutrition** — Daily summary, macros, per-meal log, add-meal search
- **Water** — Animated glass tracker with quick-add amounts
- **Sleep** — Bedtime/wake picker, quality, last-7-night chart
- **Mindfulness** — Library, breathing player with phase animation, HK mindful session logging
- **Progress** — Charts (steps, calories), consistency heatmap
- **Profile / Settings / Edit profile / Goals / Privacy / Terms**

## Setup (one-time)

### 1. Open and run

1. Open `Vitala.xcodeproj` in **Xcode 15+**.
2. Select the **Vitala** target → **Signing & Capabilities** → pick your developer **Team** so Xcode can auto-provision. (HealthKit capability is already in `Vitala.entitlements`.)
3. Pick an **iPhone 15 / 17** simulator and press **⌘R**.

That's it. No Firebase, no `GoogleService-Info.plist`, no accounts to create. The app launches with a local demo user.

> **HealthKit on simulator** returns empty data — the dashboard rings will sit at 0 until you run on a real device. Everything you log inside the app (water, meals, sleep, mindful sessions, workouts) is saved locally and persists between launches.

### Resetting the demo

- **In-app:** Profile → **Sign out** wipes the demo user and returns you to onboarding.
- **From scratch:** Delete the app from the simulator/device, or in Xcode use **Device → Erase All Content and Settings** on the simulator.

## Architecture notes

- **State machine**: `AppState.route` drives the top-level flow (splash → onboarding → profileSetup → main). `RootView` switches on it. The auth route is intentionally skipped in demo mode but the case still exists so it's a one-line revert.
- **Auth (demo mode)**: `AuthService` is now a local UserDefaults-backed store. On first launch it auto-creates a "Demo User" profile. Sign in / sign up calls succeed instantly with whatever values you pass. Sign out wipes the local profile and re-runs onboarding.
- **Data (demo mode)**: `FirestoreService` keeps everything in memory plus a single `vitala.demo.firestore` JSON blob in `UserDefaults`. Same public methods as the Firebase version (`logMeal`, `logWater`, `meals(on:)`, etc.), so views are identical.
- **HealthKit**: `HealthKitService` requests read access for steps, energy, distance, exercise minutes, heart rate, sleep, mindful minutes; write access for water, mindful sessions, and workouts. The dashboard reads daily aggregates via `HKStatisticsQuery`. Workout completion logs an `HKWorkout` via `HKWorkoutBuilder`. Water logs as `HKQuantitySample` of `dietaryWater`. **Unaffected by demo mode.**
- **Design system**: Custom `VitalaColor`, `VitalaFont`, `VitalaSpacing`, `VitalaRadius` plus a `vitalaCard()` view modifier and reusable components (`PrimaryButton`, `VitalaTextField`, `MetricCard`, `ActivityRings`, `RowItem`, etc.).
- **Charts**: Apple's Swift Charts framework powers the Sleep and Progress charts.

## Re-enabling Firebase (optional)

If after the demo you want to flip the real backend back on:

1. Restore the Firebase imports and original implementation in `Services/AuthService.swift` and `Services/FirestoreService.swift` (the demo versions kept the same method signatures, so views don't need to change).
2. Add `import FirebaseCore` and `FirebaseApp.configure()` back to `App/VitalaApp.swift`'s `init()`.
3. In `ViewModels/AppState.swift`, restore the `else if authProfile == nil { route = .auth }` branch and change `completeOnboarding()` to set `route = .auth`.
4. In `scripts/generate_pbxproj.py`, change `FIREBASE_PRODUCTS = []` back to `["FirebaseAuth", "FirebaseFirestore", "FirebaseFirestoreSwift"]`.
5. Replace `Vitala/Resources/GoogleService-Info.plist` with the real one from Firebase console (see git history for the original setup steps).
6. Run `python3 scripts/generate_pbxproj.py` and re-open Xcode.

## Regenerating the Xcode project

If you add files manually and want to refresh the project:

```bash
python3 scripts/generate_pbxproj.py
```

Or, if you prefer XcodeGen:

```bash
brew install xcodegen
xcodegen
```

Both produce a working `Vitala.xcodeproj`.

## Known caveats

- **HealthKit on simulator**: read APIs return empty data. Use a real device to see real values populate the dashboard rings and metrics.
- **Sign in with Apple**: there's a button in `SignInView` but it's unwired. Hook it to Firebase OAuthProvider when you're ready.
- **Notifications**: scheduled at 11:00, 15:30, and 21:30 daily once the user grants permission during onboarding. Adjust in `NotificationService`.
- **Firestore Codable**: relies on Firebase iOS SDK 10.17+ (where `FirebaseFirestoreSwift` was merged into `FirebaseFirestore`). The pinned minimum is 10.29.0.

## Next steps to consider

- Pull workouts/meals from a real backend (Strapi, Supabase, custom API) instead of in-app sample libraries
- Add Sign in with Apple via `ASAuthorizationAppleIDProvider`
- Build a watchOS companion that mirrors the workout timer
- Localize strings (English-only today; the project is set up for string catalogs)
- Replace the SF Symbol artwork in workouts/meals with proper imagery
