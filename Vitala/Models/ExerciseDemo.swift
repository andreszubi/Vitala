import CoreGraphics
import Foundation

// A small articulated figure that demonstrates an exercise. Poses are joint
// angles, so limbs never stretch; a demonstration is a loop of poses the
// figure eases between. Everything here is plain geometry, so it's testable
// without drawing anything.

/// Body proportions, in units of the figure's standing height.
enum FigureSize {
    static let lowerSpine = 0.15
    static let upperSpine = 0.15
    static let neck = 0.138
    static let headRadius = 0.068
    static let upperArm = 0.155
    static let forearm = 0.15
    static let thigh = 0.235
    static let shin = 0.235
    static let foot = 0.075
    static let limbWidth = 0.074
    static let torsoWidth = 0.125
    static var limbRadius: Double { limbWidth / 2 }
    static var torsoRadius: Double { torsoWidth / 2 }
}

/// Angles are in degrees: 0 points straight down, 90 the way the figure
/// faces, 180 straight up and -90 behind it.
struct FigureArm: Equatable {
    var upper: Double
    var fore: Double
}

struct FigureLeg: Equatable {
    var thigh: Double
    var shin: Double
    var foot: Double = 90
}

/// One pose, seen from the side.
struct FigurePose: Equatable {
    /// The part of the body that stays put while the rest moves.
    enum Anchor: Equatable { case nearFoot, farFoot, nearHand, nearKnee, pelvis }

    var hips: Double = 180      // pelvis to mid-back
    var chest: Double = 180     // mid-back to the base of the neck
    var head: Double = 180
    var nearArm = FigureArm(upper: 4, fore: 9)
    var farArm = FigureArm(upper: -4, fore: 3)
    var nearLeg = FigureLeg(thigh: 0, shin: 0)
    var farLeg = FigureLeg(thigh: 0, shin: 0)
    /// How far the lowest point of the body is off the ground (jumps).
    var lift: Double = 0
    var anchor: Anchor = .nearFoot
    /// Where the anchored part sits along the ground.
    var anchorX: Double = 0

    func with(_ change: (inout FigurePose) -> Void) -> FigurePose {
        var copy = self
        change(&copy)
        return copy
    }

    /// The same pose with left and right swapped.
    var mirrored: FigurePose {
        with {
            swap(&$0.nearArm, &$0.farArm)
            swap(&$0.nearLeg, &$0.farLeg)
        }
    }

    /// The pose a fraction of the way from this one to `other`.
    func blended(with other: FigurePose, _ t: Double) -> FigurePose {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        func mix(_ a: FigureArm, _ b: FigureArm) -> FigureArm {
            FigureArm(upper: mix(a.upper, b.upper), fore: mix(a.fore, b.fore))
        }
        func mix(_ a: FigureLeg, _ b: FigureLeg) -> FigureLeg {
            FigureLeg(thigh: mix(a.thigh, b.thigh), shin: mix(a.shin, b.shin), foot: mix(a.foot, b.foot))
        }
        return FigurePose(hips: mix(hips, other.hips), chest: mix(chest, other.chest), head: mix(head, other.head),
                          nearArm: mix(nearArm, other.nearArm), farArm: mix(farArm, other.farArm),
                          nearLeg: mix(nearLeg, other.nearLeg), farLeg: mix(farLeg, other.farLeg),
                          lift: mix(lift, other.lift), anchor: anchor, anchorX: anchorX)
    }
}

/// Where every joint is. x runs the way the figure faces, y runs down, and
/// the ground is y = 0.
struct FigureSkeleton: Equatable {
    var pelvis = CGPoint.zero
    var midSpine = CGPoint.zero
    var neck = CGPoint.zero
    var head = CGPoint.zero
    var nearElbow = CGPoint.zero
    var nearHand = CGPoint.zero
    var farElbow = CGPoint.zero
    var farHand = CGPoint.zero
    var nearKnee = CGPoint.zero
    var nearAnkle = CGPoint.zero
    var nearToe = CGPoint.zero
    var farKnee = CGPoint.zero
    var farAnkle = CGPoint.zero
    var farToe = CGPoint.zero
    /// Height off the ground, for the shadow.
    var lift: Double = 0

    /// Joints with the radius of what's drawn around them.
    var extents: [(point: CGPoint, radius: Double)] {
        let limb = FigureSize.limbRadius
        return [(pelvis, FigureSize.torsoRadius), (midSpine, FigureSize.torsoRadius), (neck, FigureSize.torsoRadius),
                (head, FigureSize.headRadius),
                (nearElbow, limb), (nearHand, limb), (farElbow, limb), (farHand, limb),
                (nearKnee, limb), (nearAnkle, limb), (nearToe, limb),
                (farKnee, limb), (farAnkle, limb), (farToe, limb)]
    }

    /// The space the figure takes up, down to the ground.
    var bounds: CGRect {
        var box = CGRect.null
        for (point, radius) in extents {
            box = box.union(CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        }
        return box.union(CGRect(x: box.midX, y: 0, width: 0, height: 0))
    }

    func point(_ anchor: FigurePose.Anchor) -> CGPoint {
        switch anchor {
        case .nearFoot: nearAnkle
        case .farFoot: farAnkle
        case .nearHand: nearHand
        case .nearKnee: nearKnee
        case .pelvis: pelvis
        }
    }

    func moved(dx: Double, dy: Double) -> FigureSkeleton {
        var s = self
        for path in Self.points {
            s[keyPath: path].x += dx
            s[keyPath: path].y += dy
        }
        return s
    }

    private static let points: [WritableKeyPath<FigureSkeleton, CGPoint>] = [
        \.pelvis, \.midSpine, \.neck, \.head, \.nearElbow, \.nearHand, \.farElbow, \.farHand,
        \.nearKnee, \.nearAnkle, \.nearToe, \.farKnee, \.farAnkle, \.farToe,
    ]

    /// The pose's joints with the pelvis at the origin.
    init(pose: FigurePose) {
        func step(_ from: CGPoint, _ degrees: Double, _ length: Double) -> CGPoint {
            let radians = degrees * .pi / 180
            return CGPoint(x: from.x + sin(radians) * length, y: from.y + cos(radians) * length)
        }
        midSpine = step(pelvis, pose.hips, FigureSize.lowerSpine)
        neck = step(midSpine, pose.chest, FigureSize.upperSpine)
        head = step(neck, pose.head, FigureSize.neck)
        nearElbow = step(neck, pose.nearArm.upper, FigureSize.upperArm)
        nearHand = step(nearElbow, pose.nearArm.fore, FigureSize.forearm)
        farElbow = step(neck, pose.farArm.upper, FigureSize.upperArm)
        farHand = step(farElbow, pose.farArm.fore, FigureSize.forearm)
        nearKnee = step(pelvis, pose.nearLeg.thigh, FigureSize.thigh)
        nearAnkle = step(nearKnee, pose.nearLeg.shin, FigureSize.shin)
        nearToe = step(nearAnkle, pose.nearLeg.foot, FigureSize.foot)
        farKnee = step(pelvis, pose.farLeg.thigh, FigureSize.thigh)
        farAnkle = step(farKnee, pose.farLeg.shin, FigureSize.shin)
        farToe = step(farAnkle, pose.farLeg.foot, FigureSize.foot)
        lift = pose.lift
    }

    /// The pose standing on the ground: its lowest point rests on y = 0
    /// (raised by `lift`), and its anchor sits at `anchorX`.
    static func grounded(_ pose: FigurePose) -> FigureSkeleton {
        let free = FigureSkeleton(pose: pose)
        let lowest = free.extents.map { $0.point.y + $0.radius }.max() ?? 0
        return free.moved(dx: pose.anchorX - free.point(pose.anchor).x, dy: -lowest - pose.lift)
    }
}

/// A looping demonstration of one exercise.
struct ExerciseDemo {
    enum Ease { case smooth, linear, out, `in`
        func callAsFunction(_ t: Double) -> Double {
            switch self {
            case .smooth: t * t * (3 - 2 * t)
            case .linear: t
            case .out: 1 - (1 - t) * (1 - t)
            case .in: t * t
            }
        }
    }

    /// The figure eases into `pose` over `move` seconds, then stays for `hold`.
    struct Step {
        var pose: FigurePose
        var move: Double
        var hold: Double = 0
        var ease: Ease = .smooth
    }

    enum Prop: Equatable {
        /// One dumbbell held upright in both hands.
        case dumbbellUpright
        /// A dumbbell in each hand.
        case dumbbells
    }

    let steps: [Step]
    let prop: Prop?
    /// Seconds for one loop.
    let duration: Double
    /// When the figure is in the pose that best shows the exercise.
    let keyTime: Double
    /// The space the figure moves through over the whole loop.
    let bounds: CGRect

    init(_ steps: [Step], prop: Prop? = nil, keyStep: Int = 1) {
        self.steps = steps
        self.prop = prop
        duration = steps.reduce(0) { $0 + $1.move + $1.hold }
        // Step 0 is held first; every later step is reached after the ones before it.
        var time = steps[0].hold
        for step in steps[1...].prefix(max(0, keyStep)) { time += step.move + step.hold }
        keyTime = keyStep == 0 ? 0 : time - steps[keyStep].hold
        var box = CGRect.null
        for step in steps { box = box.union(FigureSkeleton.grounded(step.pose).bounds) }
        for i in 0..<120 {
            box = box.union(Self.skeleton(steps, duration: duration, at: duration * Double(i) / 120).bounds)
        }
        // A sliver of room, so a frame between samples can't touch the edge.
        bounds = box.insetBy(dx: -0.01, dy: 0).union(CGRect(x: box.minX, y: box.minY - 0.01, width: 0, height: 0))
    }

    func skeleton(at time: Double) -> FigureSkeleton {
        Self.skeleton(steps, duration: duration, at: time)
    }

    private static func skeleton(_ steps: [Step], duration: Double, at time: Double) -> FigureSkeleton {
        guard duration > 0, steps.count > 1 else { return .grounded(steps[0].pose) }
        var t = time.truncatingRemainder(dividingBy: duration)
        if t < 0 { t += duration }
        for i in steps.indices {
            let from = steps[i]
            let to = steps[(i + 1) % steps.count]
            if t < from.hold { return .grounded(from.pose) }
            t -= from.hold
            if t < to.move { return between(from.pose, to.pose, to.ease(t / to.move)) }
            t -= to.move
        }
        return .grounded(steps[0].pose)
    }

    /// The figure part-way between two poses. When they share an anchor it
    /// stays planted exactly; otherwise the hold passes from one to the other.
    private static func between(_ a: FigurePose, _ b: FigurePose, _ t: Double) -> FigureSkeleton {
        let pose = a.blended(with: b, t)
        let free = FigureSkeleton(pose: pose)
        let lowest = free.extents.map { $0.point.y + $0.radius }.max() ?? 0
        let fromA = a.anchorX - free.point(a.anchor).x
        let fromB = b.anchorX - free.point(b.anchor).x
        return free.moved(dx: fromA + (fromB - fromA) * t, dy: -lowest - pose.lift)
    }
}

// MARK: - Library

extension ExerciseDemo {
    /// The demonstration for an exercise, matched by name.
    static func named(_ name: String) -> ExerciseDemo? {
        library[key(name)]
    }

    static func key(_ name: String) -> String {
        String(name.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }

    static let library: [String: ExerciseDemo] = {
        var all: [String: ExerciseDemo] = [:]
        func add(_ name: String, _ demo: ExerciseDemo) { all[key(name)] = demo }

        typealias Arm = FigureArm
        typealias Leg = FigureLeg
        let standing = FigurePose()
        let handsOnHips = standing.with {
            $0.nearArm = Arm(upper: -25, fore: 24)
            $0.farArm = Arm(upper: -21, fore: 27)
        }

        // On hands and toes, body in one line.
        let plank = FigurePose(hips: 108, chest: 108, head: 104,
                               nearArm: Arm(upper: 0, fore: 0), farArm: Arm(upper: 3, fore: 0),
                               nearLeg: Leg(thigh: -72, shin: -72, foot: 0),
                               farLeg: Leg(thigh: -71, shin: -73, foot: 0),
                               anchor: .nearHand)
        // On hands and knees.
        let tabletop = FigurePose(hips: 101, chest: 103, head: 100,
                                  nearArm: Arm(upper: 0, fore: 0), farArm: Arm(upper: 3, fore: 0),
                                  nearLeg: Leg(thigh: 0, shin: -90, foot: -90),
                                  farLeg: Leg(thigh: 2, shin: -90, foot: -90),
                                  anchor: .nearKnee)
        let squatLegs = Leg(thigh: 80, shin: -28)

        // Yoga
        add("Mountain pose", ExerciseDemo([
            .init(pose: standing.with {
                $0.hips = 179; $0.chest = 177; $0.head = 176
                $0.nearArm = Arm(upper: 6, fore: 13); $0.farArm = Arm(upper: -2, fore: 7)
            }, move: 2.2, hold: 0.5),
            .init(pose: standing.with {
                $0.chest = 183; $0.head = 181
                $0.nearArm = Arm(upper: 1, fore: 3); $0.farArm = Arm(upper: -4, fore: -1)
            }, move: 2.2, hold: 0.9),
        ]))

        add("Forward fold", ExerciseDemo([
            .init(pose: standing, move: 1.8, hold: 0.8),
            .init(pose: FigurePose(hips: 55, chest: 30, head: 20,
                                   nearArm: Arm(upper: -30, fore: -42), farArm: Arm(upper: -25, fore: -38),
                                   nearLeg: Leg(thigh: 12, shin: 8), farLeg: Leg(thigh: 12, shin: 8)),
                  move: 1.9, hold: 1.7),
        ]))

        let upDog = FigurePose(hips: 125, chest: 170, head: 188,
                               nearArm: Arm(upper: -12, fore: 8), farArm: Arm(upper: -8, fore: 9),
                               nearLeg: Leg(thigh: -76, shin: -86, foot: -90),
                               farLeg: Leg(thigh: -75, shin: -87, foot: -90),
                               anchor: .nearHand)
        add("Plank to up-dog", ExerciseDemo([
            .init(pose: plank, move: 1.4, hold: 0.7),
            .init(pose: plank.with {
                $0.hips = 102; $0.chest = 102; $0.head = 100
                $0.nearArm = Arm(upper: -55, fore: 10); $0.farArm = Arm(upper: -52, fore: 10)
                $0.nearLeg = Leg(thigh: -78, shin: -78, foot: 0); $0.farLeg = Leg(thigh: -77, shin: -79, foot: 0)
            }, move: 1.2, hold: 0.3),
            .init(pose: upDog, move: 1.3, hold: 1.3),
        ], keyStep: 2))

        add("Down dog", ExerciseDemo([
            .init(pose: plank, move: 1.6, hold: 0.6),
            .init(pose: FigurePose(hips: 47, chest: 47, head: 40,
                                   nearArm: Arm(upper: 47, fore: 47), farArm: Arm(upper: 50, fore: 47),
                                   nearLeg: Leg(thigh: -28, shin: -28), farLeg: Leg(thigh: -27, shin: -29),
                                   anchor: .nearHand),
                  move: 1.6, hold: 2.4),
        ]))

        add("Childs pose", ExerciseDemo([
            .init(pose: tabletop, move: 1.7, hold: 0.8),
            .init(pose: tabletop.with {
                $0.hips = 95; $0.chest = 75; $0.head = 90
                $0.nearArm = Arm(upper: 70, fore: 85); $0.farArm = Arm(upper: 73, fore: 86)
                $0.nearLeg.thigh = 68; $0.farLeg.thigh = 69
            }, move: 1.8, hold: 2.6),
        ]))

        // Strength
        add("Goblet squat", ExerciseDemo([
            .init(pose: standing.with {
                $0.nearArm = Arm(upper: 15, fore: 150); $0.farArm = Arm(upper: 19, fore: 150)
            }, move: 1.0, hold: 0.5),
            .init(pose: FigurePose(hips: 152, chest: 160, head: 172,
                                   nearArm: Arm(upper: -9, fore: 126), farArm: Arm(upper: -5, fore: 126),
                                   nearLeg: squatLegs, farLeg: squatLegs),
                  move: 1.2, hold: 0.35),
        ], prop: .dumbbellUpright))

        add("Push-up", ExerciseDemo([
            .init(pose: plank, move: 0.9, hold: 0.35),
            .init(pose: plank.with {
                $0.hips = 99; $0.chest = 99; $0.head = 97
                $0.nearArm = Arm(upper: -60, fore: 40); $0.farArm = Arm(upper: -57, fore: 40)
                $0.nearLeg = Leg(thigh: -81, shin: -81, foot: 0); $0.farLeg = Leg(thigh: -80, shin: -82, foot: 0)
            }, move: 1.0, hold: 0.25),
        ]))

        let hinge = FigurePose(hips: 125, chest: 127, head: 122,
                               nearArm: Arm(upper: 0, fore: 0), farArm: Arm(upper: 3, fore: 1),
                               nearLeg: Leg(thigh: 25, shin: -10), farLeg: Leg(thigh: 25, shin: -10))
        add("Bent-over row", ExerciseDemo([
            .init(pose: hinge, move: 1.0, hold: 0.3),
            .init(pose: hinge.with {
                $0.nearArm = Arm(upper: -80, fore: 0); $0.farArm = Arm(upper: -76, fore: 2)
            }, move: 0.8, hold: 0.35),
        ], prop: .dumbbells))

        add("Reverse lunge", ExerciseDemo([
            .init(pose: handsOnHips, move: 1.0, hold: 0.45),
            .init(pose: handsOnHips.with {
                $0.hips = 178
                $0.nearLeg = Leg(thigh: 85, shin: 0)
                $0.farLeg = Leg(thigh: -15, shin: -100, foot: 0)
            }, move: 1.1, hold: 0.35),
        ]))

        // HIIT
        let jump = FigurePose(chest: 181,
                              nearArm: Arm(upper: 165, fore: 172), farArm: Arm(upper: 159, fore: 169),
                              nearLeg: Leg(thigh: 2, shin: 0, foot: 25), farLeg: Leg(thigh: -3, shin: -2, foot: 30),
                              lift: 0.17)
        add("Jump squats", ExerciseDemo([
            .init(pose: FigurePose(hips: 150, chest: 158, head: 170,
                                   nearArm: Arm(upper: -45, fore: -25), farArm: Arm(upper: -40, fore: -19),
                                   nearLeg: squatLegs, farLeg: squatLegs),
                  move: 0.36, hold: 0.24, ease: .in),
            .init(pose: jump, move: 0.35, hold: 0.04, ease: .out),
        ]))

        let climber = FigurePose(hips: 100, chest: 100, head: 98,
                                 nearArm: Arm(upper: 0, fore: 0), farArm: Arm(upper: 3, fore: 0),
                                 nearLeg: Leg(thigh: 45, shin: -80, foot: -30),
                                 farLeg: Leg(thigh: -66, shin: -66, foot: 0),
                                 anchor: .nearHand)
        add("Mountain climbers", ExerciseDemo([
            .init(pose: climber, move: 0.3, hold: 0.05),
            .init(pose: climber.mirrored, move: 0.3, hold: 0.05),
        ], keyStep: 0))

        let crouch = FigurePose(hips: 120, chest: 110, head: 120,
                                nearArm: Arm(upper: 30, fore: 28), farArm: Arm(upper: 33, fore: 28),
                                nearLeg: Leg(thigh: 100, shin: -40), farLeg: Leg(thigh: 100, shin: -40))
        let handsDown = FigureSkeleton.grounded(crouch).nearHand.x
        add("Burpees", ExerciseDemo([
            .init(pose: standing, move: 0.3, hold: 0.2, ease: .in),
            .init(pose: crouch, move: 0.36, hold: 0.05),
            .init(pose: plank.with { $0.anchorX = handsDown }, move: 0.3, hold: 0.2),
            .init(pose: crouch, move: 0.3, hold: 0.05),
            .init(pose: jump.with { $0.lift = 0.15 }, move: 0.34, hold: 0.03),
        ], keyStep: 1))

        add("Rest", ExerciseDemo([
            .init(pose: handsOnHips.with { $0.chest = 178; $0.head = 178 }, move: 2.0, hold: 0.3),
            .init(pose: handsOnHips.with { $0.chest = 184; $0.head = 183 }, move: 2.0, hold: 0.3),
        ]))

        // Mobility
        add("Cat-cow", ExerciseDemo([
            .init(pose: tabletop.with { $0.hips = 80; $0.chest = 124; $0.head = 150 }, move: 1.6, hold: 0.7),
            .init(pose: tabletop.with { $0.hips = 125; $0.chest = 78; $0.head = 35 }, move: 1.6, hold: 0.7),
        ]))

        let pigeon = FigurePose(hips: 168, chest: 176, head: 180,
                                nearArm: Arm(upper: 28, fore: 14), farArm: Arm(upper: 36, fore: 18),
                                nearLeg: Leg(thigh: 88, shin: -68, foot: -90),
                                farLeg: Leg(thigh: -78, shin: -88, foot: -90),
                                anchor: .pelvis)
        add("Hip openers", ExerciseDemo([
            .init(pose: pigeon, move: 1.9, hold: 1.0),
            .init(pose: pigeon.with {
                $0.hips = 112; $0.chest = 84; $0.head = 80
                $0.nearArm = Arm(upper: 66, fore: 80); $0.farArm = Arm(upper: 70, fore: 82)
            }, move: 2.0, hold: 2.2),
        ]))

        add("Thoracic twist", ExerciseDemo([
            .init(pose: tabletop, move: 1.7, hold: 0.6),
            .init(pose: tabletop.with {
                $0.chest = 108; $0.head = 150
                $0.nearArm = Arm(upper: 172, fore: 178)
            }, move: 1.8, hold: 1.4),
        ]))

        // Walking and running, on the spot.
        let stride = FigurePose(hips: 178, chest: 179,
                                nearArm: Arm(upper: -22, fore: -8), farArm: Arm(upper: 22, fore: 42),
                                nearLeg: Leg(thigh: 24, shin: 14, foot: 105),
                                farLeg: Leg(thigh: -20, shin: -42, foot: 45),
                                anchor: .pelvis)
        let passing = stride.with {
            $0.nearArm = Arm(upper: 0, fore: 12); $0.farArm = Arm(upper: 0, fore: 14)
            $0.nearLeg = Leg(thigh: 4, shin: -2)
            $0.farLeg = Leg(thigh: 14, shin: -58, foot: 60)
        }
        func walk(_ pace: Double) -> ExerciseDemo {
            ExerciseDemo([stride, passing, stride.mirrored, passing.mirrored].map {
                .init(pose: $0, move: pace, ease: .linear)
            }, keyStep: 0)
        }
        add("Warm-up walk", walk(0.3))
        add("Cool down", walk(0.44))

        let runStride = FigurePose(hips: 170, chest: 172, head: 176,
                                   nearArm: Arm(upper: -45, fore: 45), farArm: Arm(upper: 40, fore: 130),
                                   nearLeg: Leg(thigh: 32, shin: -8, foot: 95),
                                   farLeg: Leg(thigh: -28, shin: -100, foot: 10),
                                   lift: 0.03, anchor: .pelvis)
        let runDrive = runStride.with {
            $0.nearArm = Arm(upper: -5, fore: 85); $0.farArm = Arm(upper: 5, fore: 95)
            $0.nearLeg = Leg(thigh: -6, shin: -24, foot: 80)
            $0.farLeg = Leg(thigh: 48, shin: -62, foot: 45)
            $0.lift = 0
        }
        add("Easy pace run", ExerciseDemo([runStride, runDrive, runStride.mirrored, runDrive.mirrored].map {
            .init(pose: $0, move: 0.17, ease: .linear)
        }, keyStep: 0))

        return all
    }()
}

// MARK: - Filmed clips

/// A filmed clip for an exercise, when one ships in the app. A clip named
/// after the exercise ("goblet-squat.mp4") is picked up automatically and
/// shown instead of the drawn figure.
enum ExerciseVideo {
    static let extensions = ["mp4", "mov", "m4v"]

    /// "Plank to up-dog" becomes "plank-to-up-dog".
    static func fileName(for exercise: String) -> String {
        exercise.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    static func url(for exercise: String, in bundle: Bundle = .main) -> URL? {
        let name = fileName(for: exercise)
        guard !name.isEmpty else { return nil }
        return extensions.lazy.compactMap { bundle.url(forResource: name, withExtension: $0) }.first
    }
}
