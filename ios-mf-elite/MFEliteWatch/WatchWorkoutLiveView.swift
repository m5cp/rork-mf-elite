//
//  WatchWorkoutLiveView.swift
//  MFEliteWatch
//
//  Live workout metrics on the wrist: elapsed time, distance, pace, heart rate
//  and active calories, with pause/resume and end. Two swipe pages — metrics and
//  controls — matching the native workout app feel.
//

import SwiftUI

struct WatchWorkoutLiveView: View {
    @Bindable var manager: WatchWorkoutManager
    @AppStorage("MF_RUN_UNIT_MILES") private var useMiles = true

    var body: some View {
        TabView {
            metricsPage
            controlsPage
        }
        .tabViewStyle(.verticalPage)
        .navigationTitle(manager.mode.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metricsPage: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(elapsedText)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(hex: manager.mode.accentHex))
                .contentTransition(.numericText())

            if manager.mode.isOutdoor {
                metricLine(value: distanceText, unit: useMiles ? "MI" : "KM")
                metricLine(value: paceText, unit: useMiles ? "/MI" : "/KM")
            }
            metricLine(value: "\(manager.heartRate)", unit: "BPM")
            metricLine(value: "\(Int(manager.activeCalories))", unit: "CAL")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private func metricLine(value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(unit)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    private var controlsPage: some View {
        VStack(spacing: 10) {
            if manager.status == .running {
                controlButton(title: "Pause", systemImage: "pause.fill", tint: .yellow) {
                    manager.pause()
                }
            } else {
                controlButton(title: "Resume", systemImage: "play.fill", tint: .green) {
                    manager.resume()
                }
            }
            controlButton(title: "End", systemImage: "stop.fill", tint: .red) {
                WKInterfaceDeviceProxy.playStop()
                manager.end()
            }
        }
        .padding(.horizontal, 6)
    }

    private func controlButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            WKInterfaceDeviceProxy.playClick()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .tint(tint)
    }

    // MARK: - Formatting

    private var elapsedText: String {
        let total = Int(manager.elapsed)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private var distanceText: String {
        let value = useMiles ? manager.distanceMeters / 1609.344 : manager.distanceMeters / 1000
        return String(format: "%.2f", value)
    }

    private var paceText: String {
        let secPerKm = manager.paceSecondsPerKm
        guard secPerKm > 0 else { return "--:--" }
        let secPerUnit = useMiles ? secPerKm * 1.609344 : secPerKm
        let m = Int(secPerUnit) / 60, s = Int(secPerUnit) % 60
        return String(format: "%d:%02d", m, s)
    }
}
