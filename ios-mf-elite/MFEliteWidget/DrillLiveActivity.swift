import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Colors

private extension Color {
    static let laInk = Color.white
    static let laMuted = Color.white.opacity(0.55)
    static let laBg = Color(red: 0.05, green: 0.05, blue: 0.06)
}

// MARK: - Shared pieces

private struct CountdownText: View {
    let state: DrillActivityAttributes.ContentState
    var font: Font
    /// True once the system considers this content out of date, i.e. the app has
    /// stopped feeding the timer. Showing a clock at all then would be a claim we
    /// can't back up, so the card says nothing rather than something wrong.
    var isStale: Bool = false

    var body: some View {
        // One reading of the clock for both the comparison and the range. Read
        // twice, an end date landing in the gap passes the check and then traps
        // building the ClosedRange.
        let now = Date.now
        return Group {
            if isStale {
                Text("—")
            } else if state.isPaused {
                Text(timeString(state.pausedRemaining))
            } else if state.endDate > now {
                Text(timerInterval: now...state.endDate, countsDown: true)
                    .monospacedDigit()
            } else {
                // The countdown ran out and no update followed. This has to be
                // handled explicitly: `Date.now...state.endDate` traps when the
                // end date is in the past, which is precisely the state a session
                // killed mid-drill leaves on the lock screen.
                Text(timeString(0))
            }
        }
        .font(font)
        .foregroundStyle(Color.laInk)
    }

    private func timeString(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct SetDots: View {
    let state: DrillActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...max(1, state.totalSets), id: \.self) { index in
                Circle()
                    .fill(index <= state.currentSet && !state.isResting ? Color.laInk : Color.white.opacity(0.22))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

private struct ControlButtons: View {
    let state: DrillActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 10) {
            Button(intent: DrillPauseToggleIntent()) {
                Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 38, height: 30)
            }
            .buttonStyle(.plain)
            .tint(Color.laInk)

            Button(intent: DrillSkipSetIntent()) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 38, height: 30)
            }
            .buttonStyle(.plain)
            .tint(Color.laInk)
        }
        .foregroundStyle(Color.laInk)
    }
}

// MARK: - Lock screen view

private struct LockScreenView: View {
    let context: ActivityViewContext<DrillActivityAttributes>
    var body: some View {
        let state = context.state
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.isResting ? "REST" : state.phaseLabel.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.laMuted)
                    Text(state.drillTitle)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Color.laInk)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                CountdownText(
                    state: state,
                    font: .system(size: 34, weight: .heavy, design: .rounded),
                    isStale: context.isStale
                )
            }
            HStack {
                SetDots(state: state)
                Spacer()
                ControlButtons(state: state)
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.laBg)
        .activitySystemActionForegroundColor(Color.laInk)
    }
}

// MARK: - Live Activity

struct DrillLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DrillActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.isResting ? "REST" : "SET \(state.currentSet)/\(state.totalSets)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.laMuted)
                        Text(state.drillTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.laInk)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(
                        state: state,
                        font: .system(size: 26, weight: .heavy, design: .rounded),
                        isStale: context.isStale
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        SetDots(state: state)
                        Spacer()
                        ControlButtons(state: state)
                    }
                }
            } compactLeading: {
                Image(systemName: state.isResting ? "pause.circle.fill" : "figure.run")
                    .foregroundStyle(Color.laInk)
            } compactTrailing: {
                CountdownText(
                    state: state,
                    font: .system(size: 14, weight: .bold, design: .rounded),
                    isStale: context.isStale
                )
            } minimal: {
                Image(systemName: "figure.run")
                    .foregroundStyle(Color.laInk)
            }
            .widgetURL(URL(string: "mfelite://drill"))
            .keylineTint(Color.laInk)
        }
    }
}
