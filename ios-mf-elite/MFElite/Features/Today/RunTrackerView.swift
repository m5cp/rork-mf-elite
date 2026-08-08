//
//  RunTrackerView.swift
//  MFElite
//
//  Athlete GPS run / on-field session tracker. Live distance (miles or km),
//  duration and pace with a live route map. Location is used only while this
//  screen is open. Fails soft with a clear message when permission is denied.
//  A finished run is banked through `WorkoutStore` — the same path an Apple
//  Watch workout takes — so it lands in the calendar and Progress tab, keeps its
//  route map, and earns XP exactly as a wrist-recorded run does.
//

import SwiftUI
import MapKit
import SwiftData

struct RunTrackerRoute: Hashable {}

struct RunTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var tracker = RunTracker()
    @State private var heart = HeartRateMonitor()
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @AppStorage("MF_RUN_UNIT_MILES") private var useMiles = true
    /// Saved so we can restore the user's brightness after boosting it outdoors.
    @State private var previousBrightness = UIScreen.main.brightness

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.s16) {
                topBar
                Spacer()
                if tracker.authDenied {
                    deniedCard
                } else {
                    metricsPanel
                    controls
                }
            }
            .padding(DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s16)
        }
        .background(DS.Colors.Bg.base)
        .preferredColorScheme(.dark)
        .onAppear {
            // Boost brightness for outdoor readability; restore on exit.
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onChange(of: heart.bpm) { _, bpm in
            tracker.recordHeartRate(bpm)
        }
        .onDisappear {
            UIScreen.main.brightness = previousBrightness
            UIApplication.shared.isIdleTimerDisabled = false
            // The screen can also be left without touching Finish — a back swipe
            // out of the pushed version, or the system tearing it down. Bank the
            // run rather than losing the trace.
            finish()
            heart.stop()
        }
    }

    // MARK: - Finishing

    /// Stop the run (if one is still in flight) and store it the same way a
    /// finished Apple Watch workout is stored: a `WorkoutRecord` with the route
    /// map, XP awarded, and both queued for the cloud. Deliberately safe to call
    /// more than once — every exit from this screen routes here, and
    /// `WorkoutStore` de-dupes on the run's id so only the first one lands.
    @MainActor
    private func finish() {
        if tracker.phase == .running || tracker.phase == .paused { tracker.stop() }
        guard let result = tracker.finishedResult() else { return }
        // Read the environment NOW, not inside the Task. This runs from
        // `onDisappear`, and by the time an escaping closure gets to it the
        // view is out of the hierarchy and its `@Environment` box has been
        // invalidated — which is exactly the back-swipe path this fix exists
        // to cover.
        let context = modelContext
        // Unstructured on purpose: the caller is usually on its way out of this
        // view, and the map render must outlive the dismissal to be saved.
        Task { await WorkoutStore.save(result, context: context) }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $camera) {
            UserAnnotation()
            if tracker.route.count > 1 {
                MapPolyline(coordinates: tracker.route)
                    .stroke(DS.Colors.Gold.base, lineWidth: 6)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .overlay(LinearGradient(
            colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.55)],
            startPoint: .top, endPoint: .bottom
        ).ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button {
                finish()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Close")
            Spacer()
            unitToggle
        }
    }

    private var unitToggle: some View {
        Button {
            useMiles.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(useMiles ? "MI" : "KM")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 48, height: 44)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .disabled(tracker.phase == .running)
        .opacity(tracker.phase == .running ? 0.4 : 1)
    }

    // MARK: - Metrics

    private var metricsPanel: some View {
        VStack(spacing: DS.Spacing.s16) {
            Text(distanceText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(useMiles ? "MILES" : "KILOMETRES")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 0) {
                metric(value: durationText, label: "Time")
                divider
                metric(value: paceText, label: useMiles ? "Pace /mi" : "Pace /km")
                divider
                heartMetric
            }
        }
        .padding(DS.Spacing.s20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 40)
    }

    @ViewBuilder
    private var heartMetric: some View {
        if heart.status == .connected && heart.bpm > 0 {
            metric(value: "\(heart.bpm)", label: "BPM")
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                heart.start()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: heart.status == .scanning ? "antenna.radiowaves.left.and.right" : "heart")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(heart.status == .scanning ? "SEARCHING" : "CONNECT HR")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        switch tracker.phase {
        case .idle:
            bigButton(title: "Start", tint: DS.Colors.Gold.base, fg: .black) { tracker.start() }
        case .running:
            HStack(spacing: DS.Spacing.s12) {
                bigButton(title: "Pause", tint: .white.opacity(0.15), fg: .white) { tracker.pause() }
            }
        case .paused:
            HStack(spacing: DS.Spacing.s12) {
                bigButton(title: "Resume", tint: DS.Colors.Gold.base, fg: .black) { tracker.resume() }
                bigButton(title: "Finish", tint: Color(hex: "#FF453A"), fg: .white) {
                    finish()
                }
            }
        case .finished:
            VStack(spacing: DS.Spacing.s12) {
                Text("Nice work! \(distanceText) \(useMiles ? "mi" : "km") in \(durationText).")
                    .style(.foot)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                HStack(spacing: DS.Spacing.s12) {
                    bigButton(title: "New run", tint: .white.opacity(0.15), fg: .white) { tracker.reset() }
                    bigButton(title: "Done", tint: DS.Colors.Gold.base, fg: .black) { dismiss() }
                }
            }
        }
    }

    private func bigButton(title: String, tint: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(tint, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var deniedCard: some View {
        VStack(spacing: DS.Spacing.s12) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("Location is off")
                .style(.title3)
                .foregroundStyle(.white)
            Text("Turn on location for MF Elite in Settings to track your distance and route.")
                .style(.foot)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(DS.Spacing.s20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Formatting

    private var distanceValue: Double {
        useMiles ? tracker.distanceMeters / 1609.344 : tracker.distanceMeters / 1000
    }

    private var distanceText: String { String(format: "%.2f", distanceValue) }

    private var durationText: String {
        let total = Int(tracker.elapsed)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private var paceText: String {
        let secPerKm = tracker.paceSecondsPerKm
        guard secPerKm > 0 else { return "--:--" }
        let secPerUnit = useMiles ? secPerKm * 1.609344 : secPerKm
        let m = Int(secPerUnit) / 60, s = Int(secPerUnit) % 60
        return String(format: "%d:%02d", m, s)
    }
}
