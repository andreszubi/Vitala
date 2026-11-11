import Foundation

/// In-app legal copy. Keep in sync with docs/privacy-policy.md.
enum LegalText {
    static let privacy = """
    Last updated: November 10, 2026

    Vitala is built so your wellness data stays yours.

    What Vitala stores
    Everything you enter — your name, an optional profile photo, birthday, height, weight and goals, and the water, meals, workouts, sleep, weights, mindful sessions, journal entries, and GLP-1 doses and side effects you log — is stored on this iPhone, in Vitala's private app storage, protected by iOS Data Protection. Unless you turn on iCloud sync, it stays only there. Vitala has no servers of its own for your data. We never receive, sell or share what you log.

    Your account
    Vitala needs an account. You can create one with Sign in with Apple, with Google, or with an email address and a password. Accounts are kept by Firebase Authentication, a service of Google, which stores your email address (or the private relay address Apple gives you), the name Apple or Google shares if any, an account identifier and, for email accounts, a protected form of your password that cannot be read back. Nothing you log in Vitala is stored with your account: no meals, workouts, sleep, weight, medicines, side effects, journal entries or Apple Health data. The account is used only to sign you in. You can delete it at any time in Settings › Account › Delete account, which also erases your data from this iPhone.

    iCloud sync (optional, off by default)
    If you turn on Settings › iCloud sync, Vitala keeps a copy of your logs (including weights and GLP-1 doses and side effects), journal entries, favourite foods, saved meals and the workouts you build in your own private iCloud storage, so your other devices signed in to the same Apple Account show the same data. Apple stores it under your account and encrypts it in transit and on its servers; Vitala's developer cannot read it. Your profile, goals and photo are not synced, and nothing Vitala reads from Apple Health is ever included. You can turn sync off at any time, and Settings › iCloud sync › Delete the iCloud copy removes the copy from iCloud.

    Apple Health
    If you choose to connect Apple Health, Vitala reads steps, active energy, exercise minutes, walking and running distance, heart rate, sleep and mindful minutes, plus the food energy, protein, carbs and fat that other apps record, to show your progress, and writes the water, sleep, mindful sessions and workouts you log in Vitala. Health data is never used for advertising or shared with anyone. You can change or revoke access at any time in Settings › Health › Data Access & Devices › Vitala.

    Food search and barcodes
    When you search for a food, Vitala sends the words you type to USDA FoodData Central, a public U.S. government nutrition database. When you scan or type a barcode, Vitala sends the barcode number to USDA FoodData Central and, if it isn't found there, to Open Food Facts, a free open food database. No name, account, device identifier or health data is sent. You can turn online lookups off in Settings › Food search.

    Camera
    The camera is used only to read barcodes while the scanner is open. Nothing is recorded or saved.

    Photos
    If you add a profile photo, you choose it with the system photo picker. Vitala only receives the single photo you select, never your library.

    Notifications
    Reminders are scheduled on your device. Nothing is sent to a server.

    Analytics and tracking
    Vitala contains no analytics, advertising or tracking code.

    Your choices
    • Export: Settings › Export my data creates a JSON file you can save or share.
    • Erase: Settings › Erase all data permanently removes everything Vitala stored on this device. With iCloud sync on, it also removes your logs from iCloud and from your other devices that sync. Data already saved to Apple Health stays in Health, where you can delete it.
    • Delete your account: Settings › Account › Delete account removes your Vitala account and erases your data from this device.
    • Deleting the app removes its data from this device, but not your account; delete the account first if you want it gone.

    Children
    Vitala is not directed to children under 13.

    Changes
    If this policy changes, the new version will appear in the app and at the address listed on the App Store.

    Contact
    Questions? Use Contact support in Settings.
    """

    static let terms = """
    Last updated: November 10, 2026

    Welcome to Vitala. By using the app you agree to these terms.

    Your account
    You need an account to use Vitala. Keep your sign-in details to yourself; you are responsible for what is done with your account. You can delete it at any time in Settings › Account.

    A wellness companion, not medical care
    Vitala helps you notice habits around movement, food, water, sleep and calm. It does not diagnose, treat or prevent any condition, and nothing in it is medical advice. Calorie, weight and other targets are general estimates for healthy adults. The GLP-1 tracker only records what you enter: it does not recommend medicines or doses, and it is not a substitute for your prescriber's instructions. Talk to a qualified healthcare professional before changing your diet or exercise, and stop any activity that causes pain, dizziness or shortness of breath.

    Your data
    Your data stays on your device, and in your own iCloud if you turn on iCloud sync, as described in the Privacy Policy. You're responsible for keeping your device secure and backed up.

    Using the app
    Use Vitala for personal, lawful purposes. The app is provided "as is" without warranties of any kind, to the extent permitted by law.

    Be kind to yourself. Take what helps; leave what doesn't.
    """
}
