//
//  WatchWorkoutPickerView.swift
//  MFEliteWatch
//
//  Apple Fitness-style workout flow on the wrist: pick a mode, a short countdown,
//  live metrics, then a summary. Owns the WatchWorkoutManager and drives which
//  screen shows from the session state.
//

import SwiftUI

struct WatchWorkoutPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WatchConnectivityReceiver.self) private var connectivity
    @State private var manager = WatchWorkoutManager()
    @State private var pendingMode: WorkoutModeID?

    var body: some View {
        Group {
            switch manager.status {
            case .idle:
                if let mode = pendingMode {
                    WatchCountdownView(mode: mode) {
                        Task { await manager.start(mode) }
                    }
                } else {
                    modeList
                }
            case .running, .paused:
                WatchWorkoutLiveView(manager: manager)
            case .ended:
                WatchWorkoutSummaryView(manager: manager) {
                    if let result = manager.result { connectivity.sendWorkout(result) }
                    dismiss()
                }
            }
        }
    }

    private var modeList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(WorkoutModeID.allCases) { mode in
                    Button {
                        WKInterfaceDeviceProxy.playClick()
                        pendingMode = mode
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: mode.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(hex: mode.accentHex))
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(mode.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(mode.isOutdoor ? "GPS route" : "Indoor")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Workout")
    }
}

/// A quick 3-2-1 countdown before a workout starts.
struct WatchCountdownView: View {
    let mode: WorkoutModeID
    let onDone: () -> Void

    @State private var count = 3

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: mode.symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color(hex: mode.accentHex))
            Text("\(count)")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(mode.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .task {
            while count > 1 {
                try? await Task.sleep(for: .seconds(1))
                WKInterfaceDeviceProxy.playClick()
                withAnimation { count -= 1 }
            }
            try? await Task.sleep(for: .seconds(1))
            WKInterfaceDeviceProxy.playSuccess()
            onDone()
        }
    }
}
