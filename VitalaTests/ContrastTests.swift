import Testing
import SwiftUI
import UIKit
@testable import Vitala

/// WCAG 2.1 contrast for every colour pairing the app uses, in Light and Dark.
struct ContrastTests {
    private static let styles: [UIUserInterfaceStyle] = [.light, .dark]

    private func color(_ name: String, _ style: UIUserInterfaceStyle) throws -> UIColor {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let named = try #require(UIColor(named: name, in: .main, compatibleWith: traits), "Missing colour \(name)")
        return named.resolvedColor(with: traits)
    }

    private func luminance(_ c: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ v: CGFloat) -> Double {
            let v = Double(v)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    private func ratio(_ a: UIColor, _ b: UIColor) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test(arguments: ["BrandInk", "BrandMuted", "BrandPrimary", "BrandCoralText", "BrandSuccess", "BrandDanger"])
    func textColorsMeetAA(_ name: String) throws {
        for style in Self.styles {
            let fg = try color(name, style)
            for bg in ["BrandCream", "BrandCard"] {
                let r = ratio(fg, try color(bg, style))
                #expect(r >= 4.5, "\(name) on \(bg) (\(style == .dark ? "dark" : "light")) is \(r)")
            }
        }
    }

    @Test(arguments: ["BrandWater", "BrandSleep", "BrandMindful"])
    func graphicColorsMeetNonTextContrast(_ name: String) throws {
        for style in Self.styles {
            let fg = try color(name, style)
            for bg in ["BrandCream", "BrandCard"] {
                #expect(ratio(fg, try color(bg, style)) >= 3, "\(name) on \(bg)")
            }
        }
    }

    @Test func whiteTextOnFilledButtons() throws {
        for style in Self.styles {
            for fill in ["BrandPrimaryFill", "BrandPrimaryFillEnd"] {
                let r = ratio(.white, try color(fill, style))
                #expect(r >= 4.5, "white on \(fill) is \(r)")
            }
        }
    }

    @Test func whiteTextOnMindfulnessSessions() {
        for session in MindfulnessLibrary.all {
            let tint = UIColor(Color(hex: session.tint))
            #expect(ratio(.white, tint) >= 4.5, "\(session.title) tint \(session.tint)")
        }
    }
}
