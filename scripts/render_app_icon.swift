// Renders Vitala's 1024×1024 App Store icon from the same leaf geometry as
// BrandMark.swift. Opaque (no alpha channel), as App Store Connect requires.
//
//   swift scripts/render_app_icon.swift Vitala/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

import AppKit
import CoreGraphics

let size = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Couldn't create context")
}
// Flip to a top-left origin so the geometry matches SwiftUI.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

let s = CGFloat(size)

// Background: deep sage gradient with a soft highlight.
let bg = CGGradient(colorsSpace: space, colors: [rgb(0x3E8A74), rgb(0x22584A)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 0), end: CGPoint(x: s, y: s), options: [])
let glow = CGGradient(colorsSpace: space,
                      colors: [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.16),
                               CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: s * 0.28, y: s * 0.22), startRadius: 0,
                       endCenter: CGPoint(x: s * 0.28, y: s * 0.22), endRadius: s * 0.7, options: [])

// Leaf geometry, inset like BrandMark (0.2 padding on a 0.6 box → scale to icon).
let inset = s * 0.18
let box = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: box.minX + x * box.width, y: box.minY + y * box.height)
}

let leaf = CGMutablePath()
leaf.move(to: p(0.20, 0.80))
leaf.addCurve(to: p(0.82, 0.18), control1: p(0.10, 0.38), control2: p(0.40, 0.12))
leaf.addCurve(to: p(0.20, 0.80), control1: p(0.88, 0.60), control2: p(0.62, 0.90))
leaf.closeSubpath()

// Soft shadow, then the cream leaf and stem.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: s * 0.018), blur: s * 0.05,
              color: CGColor(srgbRed: 0, green: 0.12, blue: 0.08, alpha: 0.35))
ctx.addPath(leaf)
ctx.setFillColor(rgb(0xFAF6EE))
ctx.fillPath()
ctx.restoreGState()

ctx.setLineCap(.round)
ctx.setStrokeColor(rgb(0xFAF6EE))
ctx.setLineWidth(box.width * 0.045)
ctx.move(to: p(0.215, 0.785))
ctx.addLine(to: p(0.10, 0.90))
ctx.strokePath()

// Vein
ctx.setStrokeColor(rgb(0x2F6B5C))
ctx.setLineWidth(box.width * 0.035)
ctx.move(to: p(0.30, 0.70))
ctx.addQuadCurve(to: p(0.70, 0.30), control: p(0.44, 0.48))
ctx.strokePath()

guard let image = ctx.makeImage() else { fatalError("Couldn't render") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("Couldn't encode PNG") }
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
