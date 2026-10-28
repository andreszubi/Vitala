import SwiftUI

/// Vitala brand palette. Calm, warm, wellness-forward.
/// Sage greens + cream backgrounds + soft coral accents.
///
/// Every text colour here meets WCAG AA (4.5:1) on both `background` and
/// `surface` in Light and Dark Mode; domain tints meet 3:1 for graphics.
enum VitalaColor {
    // Brand
    static let primary = Color("BrandPrimary")     // Deep sage — text, icons, tint
    static let sage = Color("BrandSage")           // Soft sage — decorative only
    static let cream = Color("BrandCream")         // Warm cream background
    static let coral = Color("BrandCoral")         // Soft coral — fills and rings only
    static let ink = Color("BrandInk")             // Charcoal text
    static let muted = Color("BrandMuted")         // Secondary text
    static let card = Color("BrandCard")           // Card surface

    /// Fill for surfaces that carry white text (buttons, selected chips).
    static let primaryFill = Color("BrandPrimaryFill")
    static let primaryFillEnd = Color("BrandPrimaryFillEnd")
    /// Coral that is safe to use for text and standalone icons.
    static let coralText = Color("BrandCoralText")

    // Semantic
    static let background = cream
    static let surface = card
    static let textPrimary = ink
    static let textSecondary = muted
    static let accent = coral
    static let hairline = Color("BrandHairline")
    static let success = Color("BrandSuccess")
    static let danger = Color("BrandDanger")

    // Domains
    static let water = Color("BrandWater")
    static let sleep = Color("BrandSleep")
    static let mindful = Color("BrandMindful")

    // Activity rings (a la HealthKit)
    static let ringMove = coral
    static let ringExercise = Color(red: 0.36, green: 0.72, blue: 0.40)
    static let ringStand = Color(red: 0.25, green: 0.62, blue: 0.82)

    // Gradients
    /// Button and hero-card gradient. White text stays ≥5:1 across it.
    static let primaryGradient = LinearGradient(
        colors: [primaryFill, primaryFillEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let creamGradient = LinearGradient(
        colors: [cream, Color("BrandCreamDeep")],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
