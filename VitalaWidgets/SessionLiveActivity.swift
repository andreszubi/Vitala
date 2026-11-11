import ActivityKit
import SwiftUI
import WidgetKit

/// The Lock Screen banner and Dynamic Island for a workout or a breathing
/// session in progress.
struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Palette.background)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: context.attributes.symbol)
                            .foregroundStyle(Palette.accent)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ClockText(clock: context.state.clock)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .frame(maxWidth: 76, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(1)
                        if !context.state.detail.isEmpty {
                            Text(context.state.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbol)
                    .foregroundStyle(Palette.accent)
            } compactTrailing: {
                ClockText(clock: context.state.clock)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: context.attributes.symbol)
                    .foregroundStyle(Palette.accent)
            }
            .keylineTint(Palette.accent)
        }
    }
}

/// Colours for the activity. The extension has no access to the app's
/// colour assets, so the brand colours are repeated here.
private enum Palette {
    static let background = Color(red: 0.11, green: 0.21, blue: 0.18)
    static let accent = Color(red: 0.62, green: 0.85, blue: 0.76)
}

private struct LockScreenView: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: attributes.symbol)
                .font(.title2)
                .foregroundStyle(Palette.accent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.12)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .lineLimit(1)
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if !state.detail.isEmpty {
                    Text(state.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                ClockText(clock: state.clock)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                if let stepEndsAt = state.stepEndsAt, stepEndsAt > .now {
                    // What is left of the exercise, under the workout's clock.
                    Text(timerInterval: Date.now...stepEndsAt, countsDown: true)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.accent)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Left in this exercise")
                } else if state.isPaused {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(Palette.accent)
                }
            }
            .frame(maxWidth: 96, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// The activity's clock: ticking by itself while running, still otherwise.
private struct ClockText: View {
    let clock: SessionActivityAttributes.Clock

    var body: some View {
        switch clock {
        case .down(let end):
            Text(timerInterval: Date.now...max(end, .now), countsDown: true)
                .multilineTextAlignment(.trailing)
        case .up(let start):
            Text(timerInterval: min(start, .now)...Date.distantFuture, countsDown: false)
                .multilineTextAlignment(.trailing)
        case .stopped(let seconds):
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
        }
    }
}
