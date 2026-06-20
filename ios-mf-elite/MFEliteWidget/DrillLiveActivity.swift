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

    var body: some View {
        Group {
            if state.isPaused {
                Text(timeString(state.pausedRemaining))
            } else {
                Text(timerInterval: Date.now...state.endDate, countsDown: true)
                    .monospacedDigit()
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
                CountdownText(state: state, font: .system(size: 34, weight: .heavy, design: .rounded))
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
                    CountdownText(state: state, font: .system(size: 26, weight: .heavy, design: .rounded))
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
                CountdownText(state: state, font: .system(size: 14, weight: .bold, design: .rounded))
            } minimal: {
                Image(systemName: "figure.run")
                    .foregroundStyle(Color.laInk)
            }
            .widgetURL(URL(string: "mfelite://drill"))
            .keylineTint(Color.laInk)
        }
    }
}
