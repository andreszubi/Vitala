import AVFoundation
import SwiftUI

/// Shows how an exercise is done: a filmed clip when the app ships one for
/// it, otherwise the drawn figure, otherwise the exercise's icon.
struct ExerciseDemoView: View {
    let exercise: Exercise
    /// False freezes the demonstration where it is.
    var playing = true
    /// A still of the key position, for lists.
    var still = false

    var body: some View {
        Group {
            if !still, let url = ExerciseVideo.url(for: exercise.name) {
                LoopingVideoView(url: url, playing: playing)
                    .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous))
            } else if let demo = ExerciseDemo.named(exercise.name) {
                ExerciseFigureView(name: exercise.name, demo: demo, playing: playing, still: still)
                    .equatable()
            } else {
                GeometryReader { geo in
                    Image(systemName: exercise.icon)
                        .font(.system(size: min(geo.size.width, geo.size.height) * 0.5, weight: .bold))
                        .foregroundStyle(VitalaColor.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Demonstration of \(exercise.name)")
        .accessibilityAddTraits(.isImage)
    }
}

/// The drawn figure moving through an exercise.
struct ExerciseFigureView: View, Equatable {
    let name: String
    let demo: ExerciseDemo
    var playing = true
    var still = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now
    @State private var pausedAt: Date?

    static func == (a: Self, b: Self) -> Bool {
        a.name == b.name && a.playing == b.playing && a.still == b.still
    }

    private var moving: Bool { playing && !still && !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !moving)) { context in
            let skeleton = demo.skeleton(at: moving ? context.date.timeIntervalSince(startedAt) : stillTime)
            Canvas { ctx, size in
                // A still fills its frame; a moving figure keeps to the space the whole movement needs.
                FigureRenderer(prop: demo.prop, bounds: still ? skeleton.bounds : demo.bounds,
                               tint: VitalaColor.primary, propColor: VitalaColor.textPrimary)
                    .draw(skeleton, in: &ctx, size: size)
            }
        }
        .onChange(of: moving) { _, isMoving in
            // Pick up where the figure stopped rather than jumping ahead.
            if isMoving {
                if let pausedAt { startedAt += Date.now.timeIntervalSince(pausedAt) }
                pausedAt = nil
            } else {
                pausedAt = .now
            }
        }
    }

    /// Where the figure rests when it isn't moving: mid-movement if it was
    /// paused, otherwise the position that best shows the exercise.
    private var stillTime: Double {
        if !still, !reduceMotion, let pausedAt { return pausedAt.timeIntervalSince(startedAt) }
        return demo.keyTime
    }
}

/// Draws a skeleton to fit a canvas.
struct FigureRenderer {
    let prop: ExerciseDemo.Prop?
    /// The part of the figure's space to fit into the canvas.
    let bounds: CGRect
    let tint: Color
    let propColor: Color

    func draw(_ s: FigureSkeleton, in ctx: inout GraphicsContext, size: CGSize) {
        let box = bounds
        guard box.width > 0, box.height > 0, size.width > 0, size.height > 0 else { return }
        let floor = 0.03          // room under the feet for the ground line
        let scale = min(size.width / box.width, size.height / (box.height + floor))
        let originX = size.width / 2 - box.midX * scale
        let originY = (size.height + (box.height - floor) * scale) / 2
        func p(_ point: CGPoint) -> CGPoint {
            CGPoint(x: originX + point.x * scale, y: originY + point.y * scale)
        }
        func line(_ points: [CGPoint]) -> Path {
            var path = Path()
            path.move(to: p(points[0]))
            for point in points.dropFirst() { path.addLine(to: p(point)) }
            return path
        }
        func stroke(_ width: Double) -> StrokeStyle {
            StrokeStyle(lineWidth: width * scale, lineCap: .round, lineJoin: .round)
        }
        let limb = stroke(FigureSize.limbWidth)

        // Ground and a shadow that shrinks as the figure leaves the floor.
        var ground = Path()
        ground.move(to: p(CGPoint(x: box.minX, y: 0)))
        ground.addLine(to: p(CGPoint(x: box.maxX, y: 0)))
        ctx.stroke(ground, with: .color(tint.opacity(0.16)), style: StrokeStyle(lineWidth: max(1.5, 0.014 * scale), lineCap: .round))
        let shadowWidth = 0.34 * max(0.45, 1 - s.lift * 2.5) * scale
        let shadowCentre = p(CGPoint(x: (s.pelvis.x + s.neck.x) / 2, y: 0))
        ctx.fill(Path(ellipseIn: CGRect(x: shadowCentre.x - shadowWidth / 2, y: shadowCentre.y - 0.012 * scale,
                                        width: shadowWidth, height: 0.024 * scale)),
                 with: .color(tint.opacity(0.14)))

        func dumbbell(at hand: CGPoint, upright: Bool, in layer: inout GraphicsContext) {
            // A handle with a rounded weight at each end.
            let reach = 0.07, weight = 0.03
            let axis = upright ? CGPoint(x: 0, y: 1) : CGPoint(x: 1, y: 0)
            func point(_ along: Double, _ across: Double) -> CGPoint {
                CGPoint(x: hand.x + axis.x * along - axis.y * across, y: hand.y + axis.y * along + axis.x * across)
            }
            layer.stroke(line([point(-reach, 0), point(reach, 0)]), with: .color(propColor), style: stroke(0.03))
            for side in [-1.0, 1.0] {
                layer.stroke(line([point(side * reach, -weight), point(side * reach, weight)]),
                             with: .color(propColor), style: stroke(0.052))
            }
        }

        // The far arm and leg, lighter so the near ones read in front.
        ctx.drawLayer { layer in
            layer.opacity = 0.38
            if prop == .dumbbells { dumbbell(at: s.farHand, upright: false, in: &layer) }
            layer.stroke(line([s.neck, s.farElbow, s.farHand]), with: .color(tint), style: limb)
            layer.stroke(line([s.pelvis, s.farKnee, s.farAnkle, s.farToe]), with: .color(tint), style: limb)
        }

        ctx.drawLayer { layer in
            // The spine bends through the mid-back.
            var torso = Path()
            torso.move(to: p(s.pelvis))
            torso.addQuadCurve(to: p(s.neck),
                               control: p(CGPoint(x: 2 * s.midSpine.x - (s.pelvis.x + s.neck.x) / 2,
                                                  y: 2 * s.midSpine.y - (s.pelvis.y + s.neck.y) / 2)))
            layer.stroke(torso, with: .color(tint), style: stroke(FigureSize.torsoWidth))
            let head = p(s.head), radius = FigureSize.headRadius * scale
            layer.fill(Path(ellipseIn: CGRect(x: head.x - radius, y: head.y - radius, width: radius * 2, height: radius * 2)),
                       with: .color(tint))
            layer.stroke(line([s.pelvis, s.nearKnee, s.nearAnkle, s.nearToe]), with: .color(tint), style: limb)

            // Cut a gap around the near arm so it shows against the body.
            let arm = line([s.neck, s.nearElbow, s.nearHand])
            layer.blendMode = .destinationOut
            layer.stroke(arm, with: .color(.black), style: stroke(FigureSize.limbWidth + 0.034))
            layer.blendMode = .normal
            layer.stroke(arm, with: .color(tint), style: limb)
            switch prop {
            case .dumbbellUpright: dumbbell(at: s.nearHand, upright: true, in: &layer)
            case .dumbbells: dumbbell(at: s.nearHand, upright: false, in: &layer)
            case nil: break
            }
        }
    }
}

/// A silent, looping clip.
private struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    var playing: Bool

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.load(url)
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        view.setPlaying(playing)
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.stop()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private var wantsPlay = true

        func load(_ url: URL) {
            guard let layer = layer as? AVPlayerLayer else { return }
            layer.player = player
            layer.videoGravity = .resizeAspect
            player.isMuted = true
            player.preventsDisplaySleepDuringVideoPlayback = false
            Task { [weak self] in
                // Only the picture is played, so a clip never takes over the
                // audio session and the user's own music carries on.
                let asset = AVURLAsset(url: url)
                let picture = AVMutableComposition()
                guard let source = try? await asset.loadTracks(withMediaType: .video).first,
                      let duration = try? await asset.load(.duration),
                      let track = picture.addMutableTrack(withMediaType: .video,
                                                          preferredTrackID: kCMPersistentTrackID_Invalid)
                else { return }
                try? track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: .zero)
                if let transform = try? await source.load(.preferredTransform) {
                    track.preferredTransform = transform
                }
                self?.start(AVPlayerItem(asset: picture))
            }
        }

        private func start(_ item: AVPlayerItem) {
            looper = AVPlayerLooper(player: player, templateItem: item)
            if wantsPlay { player.play() }
        }

        func setPlaying(_ playing: Bool) {
            wantsPlay = playing
            if playing { player.play() } else { player.pause() }
        }

        func stop() {
            player.pause()
            looper?.disableLooping()
            looper = nil
            player.removeAllItems()
        }
    }
}

/// A closer look at one exercise. Present inside a `NavigationStack`.
struct ExerciseDemoSheet: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playing = true

    private var canPlay: Bool {
        ExerciseVideo.url(for: exercise.name) != nil || (ExerciseDemo.named(exercise.name) != nil && !reduceMotion)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: VitalaSpacing.md) {
                ExerciseDemoView(exercise: exercise, playing: playing)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(VitalaSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: VitalaRadius.lg, style: .continuous)
                        .fill(VitalaColor.primary.opacity(0.08)))

                VStack(alignment: .leading, spacing: 6) {
                    if let prescription = exercise.prescription {
                        Text(prescription)
                            .font(VitalaFont.bodyMedium(15))
                            .foregroundStyle(VitalaColor.primary)
                    }
                    Text(exercise.instructions)
                        .font(VitalaFont.body(16))
                        .foregroundStyle(VitalaColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(VitalaSpacing.md)
                .surfaceCard()
                .accessibilityElement(children: .combine)
                if canPlay {
                    Button {
                        playing.toggle()
                    } label: {
                        Label(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill")
                            .font(VitalaFont.bodyMedium(15))
                            .frame(minWidth: 110, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(VitalaColor.primary)
                }

            }
            .padding(VitalaSpacing.lg)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
