import CoreGraphics
import Foundation
import Testing
@testable import Vitala

struct ExerciseDemoTests {
    private var exercises: [Exercise] { WorkoutLibrary.all.flatMap(\.exercises) }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        Double(hypot(a.x - b.x, a.y - b.y))
    }

    /// Moments spread across one loop, off the beat of anything the model samples itself.
    private func frames(_ demo: ExerciseDemo) -> [FigureSkeleton] {
        (0..<173).map { demo.skeleton(at: demo.duration * Double($0) / 173) }
    }

    @Test func everyLibraryExerciseHasADemonstration() {
        for exercise in exercises {
            #expect(ExerciseDemo.named(exercise.name) != nil, "\(exercise.name)")
        }
        #expect(ExerciseDemo.named("An exercise nobody drew") == nil)
        // Matching ignores case and punctuation.
        #expect(ExerciseDemo.named("child's POSE") != nil)
    }

    @Test func limbsNeverStretch() {
        for (name, demo) in ExerciseDemo.library {
            for s in frames(demo) {
                #expect(abs(distance(s.neck, s.nearElbow) - FigureSize.upperArm) < 1e-9, "\(name)")
                #expect(abs(distance(s.nearElbow, s.nearHand) - FigureSize.forearm) < 1e-9, "\(name)")
                #expect(abs(distance(s.pelvis, s.farKnee) - FigureSize.thigh) < 1e-9, "\(name)")
                #expect(abs(distance(s.farKnee, s.farAnkle) - FigureSize.shin) < 1e-9, "\(name)")
                #expect(abs(distance(s.pelvis, s.midSpine) - FigureSize.lowerSpine) < 1e-9, "\(name)")
            }
        }
    }

    @Test func theFigureStaysOnTheGroundUnlessItJumps() {
        for (name, demo) in ExerciseDemo.library {
            for s in frames(demo) {
                let lowest = s.extents.map { Double($0.point.y) + $0.radius }.max() ?? 0
                // Nothing sinks into the floor, and the lowest point rests on it.
                #expect(lowest <= 1e-9, "\(name) sinks")
                #expect(abs(lowest + s.lift) < 1e-9, "\(name) floats")
                #expect(s.lift >= 0 && s.lift < 0.25, "\(name)")
            }
        }
    }

    @Test func plantedHandsAndFeetDoNotSlide() {
        // Where one part of the body carries the whole movement, it stays put.
        let planted: [(String, KeyPath<FigureSkeleton, CGPoint>)] = [
            ("Goblet squat", \.nearAnkle), ("Bent-over row", \.nearAnkle), ("Reverse lunge", \.nearAnkle),
            ("Forward fold", \.nearAnkle), ("Jump squats", \.nearAnkle),
            ("Push-up", \.nearHand), ("Plank to up-dog", \.nearHand), ("Down dog", \.nearHand),
            ("Mountain climbers", \.nearHand), ("Cat-cow", \.nearKnee), ("Childs pose", \.nearKnee),
        ]
        for (name, joint) in planted {
            let demo = ExerciseDemo.named(name)!
            let xs = frames(demo).map { Double($0[keyPath: joint].x) }
            #expect((xs.max() ?? 0) - (xs.min() ?? 0) < 1e-9, "\(name)")
        }
    }

    @Test func movementIsSmoothAndLoops() {
        for (name, demo) in ExerciseDemo.library {
            #expect(demo.duration > 0.5 && demo.duration < 10, "\(name)")
            // The loop closes: the end meets the start.
            #expect(demo.skeleton(at: demo.duration) == demo.skeleton(at: 0), "\(name)")
            #expect(demo.skeleton(at: -0.25) == demo.skeleton(at: demo.duration - 0.25), "\(name)")
            // No joint teleports between frames a 60th of a second apart.
            var previous = demo.skeleton(at: 0)
            for i in 1...Int(demo.duration * 60) {
                let next = demo.skeleton(at: Double(i) / 60)
                for (a, b) in zip(previous.extents, next.extents) {
                    #expect(distance(a.point, b.point) < 0.12, "\(name) jumps at frame \(i)")
                }
                previous = next
            }
        }
    }

    @Test func boundsHoldTheWholeMovement() {
        for (name, demo) in ExerciseDemo.library {
            let box = demo.bounds.insetBy(dx: -1e-6, dy: -1e-6)
            #expect(box.maxY <= 1e-5, "\(name): the ground is the bottom edge")
            for s in frames(demo) {
                #expect(box.contains(s.bounds), "\(name)")
            }
            // The still shown in lists is a moment of the loop.
            #expect((0...demo.duration).contains(demo.keyTime), "\(name)")
        }
    }

    @Test func mirroringSwapsSides() {
        let pose = FigurePose(nearArm: FigureArm(upper: 10, fore: 20), farArm: FigureArm(upper: -30, fore: -40),
                              nearLeg: FigureLeg(thigh: 50, shin: 60), farLeg: FigureLeg(thigh: -70, shin: -80))
        #expect(pose.mirrored.nearArm == pose.farArm && pose.mirrored.farLeg == pose.nearLeg)
        #expect(pose.mirrored.mirrored == pose)
    }

    @Test func prescriptionsReadNaturally() {
        func exercise(seconds: Int = 0, reps: Int? = nil, sets: Int? = nil) -> Exercise {
            Exercise(name: "x", seconds: seconds, reps: reps, sets: sets, instructions: "", icon: "")
        }
        #expect(exercise(seconds: 45).prescription == "45 sec")
        #expect(exercise(seconds: 180).prescription == "3 min")
        #expect(exercise(seconds: 40, sets: 4).prescription == "4 × 40 sec")
        #expect(exercise(reps: 12, sets: 3).prescription == "3 × 12 reps")
        #expect(exercise(reps: 8).prescription == "8 reps")
        #expect(exercise().prescription == nil)
    }

    @Test func clipsAreFoundByExerciseName() {
        #expect(ExerciseVideo.fileName(for: "Plank to up-dog") == "plank-to-up-dog")
        #expect(ExerciseVideo.fileName(for: "Child's pose") == "child-s-pose")
        #expect(ExerciseVideo.fileName(for: "  Goblet   squat ") == "goblet-squat")
        // No clips ship today, so every exercise falls back to the drawn figure.
        for exercise in exercises {
            #expect(ExerciseVideo.url(for: exercise.name) == nil, "\(exercise.name)")
        }
        #expect(ExerciseVideo.url(for: "") == nil)
    }
}
