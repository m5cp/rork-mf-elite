//
//  WatchWorkoutSummaryView.swift
//  MFEliteWatch
//
//  Post-workout summary on the wrist: totals for time, distance, pace, calories
//  and heart-rate range. "Done" syncs the workout to the phone and dismisses.
//

import SwiftUI

struct WatchWorkoutSummaryView: View {
    @Bindable var manager: WatchWorkoutManager
    let onDone: () -> Void

    @AppStorage("MF_RUN_UNIT_MILES") private var useMiles = true

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: manager.mode.symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color(hex: manager.mode.accentHex))
                Text(manager.mode.displayName)
                    .font(.system(size: 15, weight: .bold))

                VStack(spacing: 4) {
                    summaryRow("Time", elapsedText)
                    if manager.mode.isOutdoor {
                        summaryRow("Distance", "\(distanceText) \(useMiles ? "mi" : "km")")
                        summaryRow("Avg pace", paceText)
                    }
                    summaryRow("Calories", "\(Int(manager.activeCalories))")
                    if manager.maxHeartRate > 0 {
                        summaryRow("Heart rate", "\(manager.avgHeartRate)–\(manager.maxHeartRate) bpm")
                    }
                }
                .padding(.top, 4)

                Button("Done") {
                    WKInterfaceDeviceProxy.playSuccess()
                    onDone()
                }
                .tint(.green)
                .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("Summary")
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
    }

    private var elapsedText: String {
        let total = manager.result?.durationSec ?? Int(manager.elapsed)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private var distanceText: String {
        let meters = manager.result?.distanceMeters ?? manager.distanceMeters
        let value = useMiles ? meters / 1609.344 : meters / 1000
        return String(format: "%.2f", value)
    }

    private var paceText: String {
        let secPerKm = manager.paceSecondsPerKm
        guard secPerKm > 0 else { return "--:--" }
        let secPerUnit = useMiles ? secPerKm * 1.609344 : secPerKm
        let m = Int(secPerUnit) / 60, s = Int(secPerUnit) % 60
        return String(format: "%d:%02d/\(useMiles ? "mi" : "km")", m, s)
    }
}
