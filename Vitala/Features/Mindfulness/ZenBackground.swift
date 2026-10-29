import SwiftUI

/// Calm moving scenes behind the breathing player. Drawn live on the device,
/// like the session sound — no video files to license, download or store.
enum ZenScene: String, CaseIterable, Identifiable {
    case automatic, ocean, rain, stars, mist, aurora, off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: "Match session"
        case .ocean: "Ocean at dusk"
        case .rain: "Rain on water"
        case .stars: "Starry night"
        case .mist: "Misty mountains"
        case .aurora: "Aurora"
        case .off: "Plain colour"
        }
    }

    var icon: String {
        switch self {
        case .automatic: "wand.and.stars"
        case .ocean: "water.waves"
        case .rain: "cloud.rain.fill"
        case .stars: "moon.stars.fill"
        case .mist: "mountain.2.fill"
        case .aurora: "sparkles"
        case .off: "circle.slash"
        }
    }

    /// The scene to draw: a specific choice, or one that suits the session.
    func resolved(for category: MindfulnessSession.Category) -> ZenScene {
        guard self == .automatic else { return self }
        switch category {
        case .breathing: return .ocean
        case .stress: return .rain
        case .sleep: return .stars
        case .focus: return .mist
        case .gratitude: return .aurora
        }
    }
}

/// Full-screen animated background. The still parts of a scene are drawn
/// once; only the moving parts redraw, 20 times a second, and nothing is
/// blurred per frame, so the main thread stays free for taps and menus.
/// Pauses on a still frame with Reduce Motion, and adds a soft shade so white
/// text on top stays readable.
struct ZenBackground: View {
    let scene: ZenScene
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if scene == .off || scene == .automatic {
                LinearGradient(colors: [tint, tint.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                    .background(Color.black)
            } else {
                ZStack {
                    Canvas { context, size in ZenPainter.backdrop(scene, context, size) }
                    TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { timeline in
                        // A fixed moment when motion is reduced; otherwise wall-clock seconds.
                        let t = reduceMotion ? 40 : timeline.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 86_400)
                        ZStack {
                            Canvas(rendersAsynchronously: true) { context, size in
                                ZenPainter.motion(scene, context, size, t)
                            }
                            if scene == .aurora {
                                // Drawn sharp, then softened by a blur the GPU
                                // applies to the whole layer, which is far cheaper
                                // than blurring inside the Canvas every frame.
                                Canvas(rendersAsynchronously: true) { context, size in
                                    ZenPainter.auroraRibbons(context, size, t)
                                }
                                .blur(radius: 18)
                                .blendMode(.plusLighter)
                                Canvas(rendersAsynchronously: true) { context, size in
                                    ZenPainter.auroraDetail(context, size, t)
                                }
                                .blur(radius: 2.5)
                                .blendMode(.plusLighter)
                            }
                        }
                    }
                }
                .overlay {
                    LinearGradient(stops: [.init(color: .black.opacity(0.28), location: 0),
                                           .init(color: .black.opacity(0.08), location: 0.45),
                                           .init(color: .black.opacity(0.38), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    /// A soft shadow that keeps white text legible over the brighter parts of
    /// a scene, such as a sunset or the aurora.
    func readableOnScene() -> some View {
        shadow(color: .black.opacity(0.35), radius: 6, y: 1)
    }
}

/// The drawing for each scene: a still backdrop and a light layer of motion
/// on top. `t` is seconds; every movement is a slow function of it, so
/// scenes loop smoothly and need no stored state.
enum ZenPainter {
    private static let twoPi = 2 * Double.pi

    static func backdrop(_ scene: ZenScene, _ ctx: GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let rect = CGRect(origin: .zero, size: size)
        switch scene {
        case .ocean:
            let horizon = h * oceanHorizon
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(stops: [.init(color: Color(hex: "#1B1D45"), location: 0),
                                 .init(color: Color(hex: "#4A3E70"), location: 0.38),
                                 .init(color: Color(hex: "#E09378"), location: 0.62),
                                 .init(color: Color(hex: "#3A3463"), location: 0.65),
                                 .init(color: Color(hex: "#121630"), location: 1)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            let sun = CGPoint(x: w * 0.5, y: horizon - h * 0.035)
            ctx.fill(Path(rect), with: .radialGradient(Gradient(colors: [Color(hex: "#FFC9A0").opacity(0.55), .clear]),
                                                       center: sun, startRadius: 0, endRadius: w * 0.6))
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - w * 0.085, y: sun.y - w * 0.085, width: w * 0.17, height: w * 0.17)),
                     with: .color(Color(hex: "#FFDDB5").opacity(0.92)))
            // The sea covers the lower half of the sun.
            ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)),
                     with: .linearGradient(Gradient(colors: [Color(hex: "#3A3463"), Color(hex: "#121630")]),
                                           startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))
        case .rain:
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Color(hex: "#13343A"), Color(hex: "#1F4B4C"), Color(hex: "#0B2125")]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            ctx.fill(Path(rect), with: .radialGradient(Gradient(colors: [Color(hex: "#8FC1BC").opacity(0.22), .clear]),
                                                       center: CGPoint(x: w * 0.5, y: h * 0.3), startRadius: 0, endRadius: h * 0.6))
        case .stars:
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Color(hex: "#060A1E"), Color(hex: "#121A3C"), Color(hex: "#2B2853")]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            // Off to the side, clear of the session title.
            let moon = CGPoint(x: w * 0.85, y: h * 0.27)
            ctx.fill(Path(rect), with: .radialGradient(Gradient(colors: [Color(hex: "#C9D3FF").opacity(0.25), .clear]),
                                                       center: moon, startRadius: 0, endRadius: w * 0.55))
            ctx.fill(Path(ellipseIn: CGRect(x: moon.x - w * 0.055, y: moon.y - w * 0.055, width: w * 0.11, height: w * 0.11)),
                     with: .color(Color(hex: "#F3EEDB")))
            ridge(ctx, size, base: 0.82, height: 0.07, seed: 1.3, drift: 0, color: Color(hex: "#1A1D3D"))
            ridge(ctx, size, base: 0.9, height: 0.06, seed: 4.1, drift: 0, color: Color(hex: "#0C0F26"))
        case .mist:
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Color(hex: "#2D4256"), Color(hex: "#5F7C88"), Color(hex: "#93ABA8")]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.7)))
            ctx.fill(Path(rect), with: .radialGradient(Gradient(colors: [Color(hex: "#F4E3C8").opacity(0.35), .clear]),
                                                       center: CGPoint(x: w * 0.3, y: h * 0.3), startRadius: 0, endRadius: w * 0.8))
        case .aurora:
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Color(hex: "#03101C"), Color(hex: "#0A2232"), Color(hex: "#11303A")]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            ridge(ctx, size, base: 0.84, height: 0.08, seed: 2.9, drift: 0, color: Color(hex: "#071820"))
            ridge(ctx, size, base: 0.92, height: 0.05, seed: 5.2, drift: 0, color: Color(hex: "#030C12"))
        case .automatic, .off:
            break
        }
    }

    static func motion(_ scene: ZenScene, _ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        switch scene {
        case .ocean: ocean(ctx, size, t)
        case .rain: rain(ctx, size, t)
        case .stars: stars(ctx, size, t)
        case .mist: mist(ctx, size, t)
        case .aurora: aurora(ctx, size, t)
        case .automatic, .off: break
        }
    }

    // MARK: Ocean at dusk

    /// Low enough that the sun sets below the breathing guide, not behind its text.
    private static let oceanHorizon = 0.64

    private static func ocean(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        let horizon = h * oceanHorizon
        let sunX = w * 0.5

        // Shimmering path of light on the water.
        var glints = ctx
        glints.blendMode = .plusLighter
        for k in 0..<22 {
            let p = Double(k) / 22
            let y = horizon + 4 + (h - horizon) * 0.75 * p * p
            let width = w * (0.04 + 0.22 * p) * (0.55 + 0.45 * sin(t * 0.9 + Double(k) * 1.7))
            glints.fill(Path(roundedRect: CGRect(x: sunX - width / 2 + 6 * sin(t * 0.5 + Double(k)), y: y,
                                                 width: width, height: 1.5 + 3 * p), cornerRadius: 2),
                        with: .color(Color(hex: "#FFD2A8").opacity(0.32 * (1 - p) + 0.06)))
        }

        // Rolling swells, slower and smaller towards the horizon.
        for i in 0..<6 {
            let depth = Double(i + 1) / 7
            let y0 = horizon + (h - horizon) * pow(depth, 1.5)
            let amp = 2 + Double(i) * 3.2
            let wavelength = w * (0.32 + Double(i) * 0.12)
            let speed = 0.12 + Double(i) * 0.05
            var path = Path()
            path.move(to: CGPoint(x: 0, y: h))
            var x = 0.0
            while x <= w + 12 {
                let y = y0 + amp * sin(twoPi * (x / wavelength) + t * speed * twoPi * 0.3)
                    + amp * 0.45 * sin(twoPi * (x / (wavelength * 0.47)) - t * speed * 1.3)
                path.addLine(to: CGPoint(x: x, y: y))
                x += 12
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
            ctx.fill(path, with: .color(Color(hex: "#262A55").opacity(0.18 + depth * 0.12)))
            ctx.stroke(path, with: .color(Color(hex: "#F3B898").opacity(0.10)), lineWidth: 1)
        }
    }

    // MARK: Rain on water

    private static func rain(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        // Ripples: each drop lands somewhere new every cycle and spreads out.
        var rings = ctx
        rings.blendMode = .plusLighter
        for i in 0..<16 {
            let period = 3.6 + Double(i % 5) * 0.8
            let shifted = t + hash(i, 0) * period
            let cycle = Int(floor(shifted / period))
            let progress = (shifted / period) - Double(cycle)
            let cx = w * (0.06 + 0.88 * hash(i, cycle))
            let cy = h * (0.3 + 0.66 * hash(i + 97, cycle))
            let maxR = w * 0.16 * (0.55 + 0.45 * (cy / h))
            for ring in 0..<3 {
                let p = progress - Double(ring) * 0.12
                guard p > 0 else { continue }
                let r = p * maxR
                rings.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r * 0.34, width: r * 2, height: r * 0.68)),
                             with: .color(.white.opacity(pow(max(0, 1 - p), 1.6) * 0.45)), lineWidth: 1.1)
            }
        }

        // Fine rain falling in front, drawn as one path.
        var streaks = Path()
        for i in 0..<60 {
            let speed = h * (0.55 + 0.3 * hash(i, 7))
            let y = (t * speed + hash(i, 5) * h).truncatingRemainder(dividingBy: h)
            let x = w * hash(i, 3) + 0.08 * y
            streaks.move(to: CGPoint(x: x, y: y))
            streaks.addLine(to: CGPoint(x: x - 2, y: y + 16))
        }
        ctx.stroke(streaks, with: .color(.white.opacity(0.10)), lineWidth: 1)
    }

    // MARK: Starry night

    private static func stars(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        // Kept above the hills, which are part of the backdrop.
        drawStars(ctx, size, t, count: 150, maxY: 0.7, brightness: 1)

        // A shooting star every so often.
        let period = 13.0
        let cycle = Int(floor(t / period))
        let local = t / period - Double(cycle)
        if local < 0.07 {
            let p = local / 0.07
            let start = CGPoint(x: w * (0.1 + 0.4 * hash(cycle, 11)), y: h * (0.06 + 0.2 * hash(cycle, 13)))
            let head = CGPoint(x: start.x + w * 0.35 * p, y: start.y + h * 0.12 * p)
            let tail = CGPoint(x: head.x - w * 0.12, y: head.y - h * 0.04)
            var trail = Path()
            trail.move(to: tail)
            trail.addLine(to: head)
            ctx.stroke(trail, with: .linearGradient(Gradient(colors: [.clear, .white.opacity(0.85 * (1 - p))]),
                                                    startPoint: tail, endPoint: head), lineWidth: 1.5)
        }
    }

    // MARK: Misty mountains

    private static func mist(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        let ridges: [(base: Double, height: Double, color: Color)] = [
            (0.46, 0.14, Color(hex: "#7E9699")), (0.56, 0.13, Color(hex: "#5F7B7C")), (0.66, 0.12, Color(hex: "#43615F")),
            (0.77, 0.11, Color(hex: "#2C4744")), (0.88, 0.1, Color(hex: "#18302D")),
        ]
        for (i, r) in ridges.enumerated() {
            ridge(ctx, size, base: r.base, height: r.height, seed: Double(i) * 2.3 + 0.7,
                  drift: t * 0.6 * Double(i + 1), color: r.color)
            // Fog drifting between the ridges: soft-edged gradients, no blur.
            for k in 0..<2 {
                let span = w * 1.8
                let x = (t * (5 + Double(i) * 3) + hash(i, k) * span).truncatingRemainder(dividingBy: span) - w * 0.4
                let y = h * (r.base - 0.02 + 0.03 * Double(k))
                let bank = CGRect(x: x, y: y, width: w * 0.9, height: h * 0.08)
                ctx.fill(Path(ellipseIn: bank), with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.24), .white.opacity(0)]),
                    center: CGPoint(x: bank.midX, y: bank.midY), startRadius: 0, endRadius: bank.width / 2))
            }
        }
    }

    // MARK: Aurora

    private static func aurora(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        drawStars(ctx, size, t, count: 90, maxY: 0.7, brightness: 0.7)
    }

    private static let auroraRibbonStyles: [(y: Double, color: Color, speed: Double)] = [
        (0.22, Color(hex: "#5CF2B4"), 0.11), (0.3, Color(hex: "#38C9C9"), 0.08), (0.38, Color(hex: "#9B7CF2"), 0.06),
    ]

    /// The middle line and thickness of ribbon `i` at horizontal position `u`.
    private static func auroraRibbon(_ i: Int, _ u: Double, _ t: Double, _ h: Double) -> (centre: Double, thickness: Double) {
        let r = auroraRibbonStyles[i]
        let centre = h * r.y + h * 0.05 * sin(twoPi * (u * 0.8 + t * r.speed) + Double(i))
            + h * 0.02 * sin(twoPi * (u * 2.1 - t * r.speed * 1.7))
        let thickness = h * (0.06 + 0.04 * sin(twoPi * (u * 1.4 + t * 0.05 * Double(i + 1))))
        return (centre, thickness)
    }

    /// Three soft ribbons of green, teal and violet light drifting across the
    /// sky. Drawn sharp-edged; the view blurs them into a glow.
    static func auroraRibbons(_ context: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        var lights = context
        lights.blendMode = .plusLighter
        for (i, ribbon) in auroraRibbonStyles.enumerated() {
            var top: [CGPoint] = [], bottom: [CGPoint] = []
            var x = -20.0
            while x <= w + 20 {
                let r = auroraRibbon(i, x / w, t, h)
                top.append(CGPoint(x: x, y: r.centre - r.thickness))
                bottom.append(CGPoint(x: x, y: r.centre + r.thickness * 0.4))
                x += 10
            }
            var band = Path()
            band.addLines(top)
            band.addLines(bottom.reversed())
            band.closeSubpath()
            lights.fill(band, with: .linearGradient(
                Gradient(stops: [.init(color: ribbon.color.opacity(0), location: 0),
                                 .init(color: ribbon.color.opacity(0.55), location: 0.65),
                                 .init(color: ribbon.color.opacity(0.1), location: 1)]),
                startPoint: CGPoint(x: 0, y: h * (ribbon.y - 0.12)), endPoint: CGPoint(x: 0, y: h * (ribbon.y + 0.06))))
        }
    }

    /// Fine detail over the soft ribbons: a glowing line along each ribbon's
    /// lower edge, and faint streaks of light rising from it that sway and
    /// fade slowly. Spacing, width and height are irregular, so they read as
    /// rays rather than stripes. Lightly blurred by the view.
    static func auroraDetail(_ context: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        var lights = context
        lights.blendMode = .plusLighter
        for (i, ribbon) in auroraRibbonStyles.enumerated() {
            // The lower edge, brightest where the ribbon is thickest.
            var edge = Path()
            var x = -20.0
            edge.move(to: CGPoint(x: x, y: auroraRibbon(i, x / w, t, h).centre))
            while x <= w + 20 {
                let r = auroraRibbon(i, x / w, t, h)
                edge.addLine(to: CGPoint(x: x, y: r.centre + r.thickness * 0.15))
                x += 8
            }
            lights.stroke(edge, with: .color(ribbon.color.opacity(i == 2 ? 0.12 : 0.22)), lineWidth: 2.5)

            // Rays rise from the green and teal ribbons only; violet stays soft.
            guard i < 2 else { continue }
            let count = i == 0 ? 70 : 55
            for k in 0..<count {
                let seed = k * 3 + i * 1_000
                let u = hash(seed, 1) + 0.012 * sin(t * (0.05 + 0.04 * hash(seed, 2)) + Double(k))
                let r = auroraRibbon(i, u, t, h)
                // Each ray brightens and fades on its own slow cycle.
                let pulse = 0.5 + 0.5 * sin(t * (0.15 + 0.35 * hash(seed, 3)) + hash(seed, 4) * twoPi)
                let alpha = (0.05 + 0.2 * hash(seed, 5)) * pulse
                guard alpha > 0.02 else { continue }
                let width = 1.5 + 3.5 * hash(seed, 6)
                let base = r.centre + r.thickness * 0.3
                let top = r.centre - r.thickness * (0.8 + 1.4 * hash(seed, 7))
                let rect = CGRect(x: u * w - width / 2, y: top, width: width, height: base - top)
                lights.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .linearGradient(
                    Gradient(stops: [.init(color: ribbon.color.opacity(0), location: 0),
                                     .init(color: ribbon.color.opacity(alpha), location: 0.75),
                                     .init(color: ribbon.color.opacity(0), location: 1)]),
                    startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: base)))
            }
        }
    }

    // MARK: Shared pieces

    /// A softly irregular hill or mountain line filled to the bottom edge.
    private static func ridge(_ context: GraphicsContext, _ size: CGSize, base: Double, height: Double,
                              seed: Double, drift: Double, color: Color) {
        let w = size.width, h = size.height
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h))
        var x = 0.0
        while x <= w + 8 {
            let u = (x + drift) / w
            let y = h * base - h * height * (0.55 + 0.25 * sin(twoPi * (u * 0.9 + seed))
                                            + 0.15 * sin(twoPi * (u * 2.3 + seed * 1.7))
                                            + 0.05 * sin(twoPi * (u * 5.1 + seed * 0.3)))
            path.addLine(to: CGPoint(x: x, y: y))
            x += 8
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }

    private static func drawStars(_ context: GraphicsContext, _ size: CGSize, _ t: Double,
                                  count: Int, maxY: Double, brightness: Double) {
        for i in 0..<count {
            let x = size.width * hash(i, 101)
            let y = size.height * maxY * pow(hash(i, 103), 1.3)
            let r = 0.5 + 1.3 * pow(hash(i, 107), 3)
            let twinkle = 0.5 + 0.5 * sin(t * (0.6 + 1.6 * hash(i, 109)) + hash(i, 113) * twoPi)
            let alpha = brightness * (0.25 + 0.75 * twinkle) * (0.4 + 0.6 * hash(i, 127))
            context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(alpha)))
        }
    }

    /// A repeatable pseudo-random number in 0..<1 for a pair of integers.
    static func hash(_ a: Int, _ b: Int) -> Double {
        var x = UInt64(bitPattern: Int64(a &* 73_856_093 ^ b &* 19_349_663))
        x ^= x >> 33; x &*= 0xff51afd7ed558ccd
        x ^= x >> 33; x &*= 0xc4ceb9fe1a85ec53
        x ^= x >> 33
        return Double(x % 1_000_000) / 1_000_000
    }
}
