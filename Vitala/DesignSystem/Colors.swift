import SwiftUI

/// Vitala brand palette. Calm, warm, wellness-forward.
/// Sage greens + cream backgrounds + soft coral accents.
enum VitalaColor {
    // Brand
    static let primary = Color("BrandPrimary")     // Deep sage #2F6B5C
    static let sage = Color("BrandSage")           // Soft sage  #88B5A6
    static let cream = Color("BrandCream")         // Warm cream #FAF6EE
    static let coral = Color("BrandCoral")         // Soft coral #E8806E
    static let ink = Color("BrandInk")             // Charcoal text #1F2A28
    static let muted = Color("BrandMuted")         // Muted gray #8A938F
    static let card = Color("BrandCard")           // Card surface #FFFFFF

    // Semantic
    static let background = cream
    static let surface = card
    static let textPrimary = ink
    static let textSecondary = muted
    static let accent = coral
    static let success = Color(red: 0.36, green: 0.66, blue: 0.51)
    static let warning = Color(red: 0.96, green: 0.71, blue: 0.31)
    static let danger  = Color(red: 0.86, green: 0.34, blue: 0.34)

    // Activity rings (a la HealthKit)
    static let ringMove = coral
    static let ringExercise = Color(red: 0.55, green: 0.84, blue: 0.50)
    static let ringStand = Color(red: 0.42, green: 0.78, blue: 0.91)

    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [primary, sage],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coralGradient = LinearGradient(
        colors: [coral, Color(red: 0.95, green: 0.62, blue: 0.49)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let creamGradient = LinearGradient(
        colors: [cream, Color(red: 0.93, green: 0.96, blue: 0.92)],
        startPoint: .top,
        endPoint: .bottom
    )
}
