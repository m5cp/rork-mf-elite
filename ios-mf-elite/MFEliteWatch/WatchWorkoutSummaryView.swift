//
//  WatchWorkoutSummaryView.swift
//  MFEliteWatch
//
//  Post-workout summary on the wrist: the recorded route, then totals for time,
//  distance, pace, calories and heart-rate range. "Done" syncs the workout to
//  the phone and dismisses.
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

                if routePoints.count > 1 {
                    WatchRouteTrace(points: routePoints, color: Color(hex: manager.mode.accentHex))
                        .frame(height: 74)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 2)
                }

                VStack(spacing: 4) {
                    summaryRow("Time", elapsedText)
                    if showsDistance {
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

    /// The finished result's route. Read from the result rather than the
    /// manager's live `route` so the summary shows exactly what was sent to the
    /// phone — the same points, drawn the same way, on both devices.
    private var routePoints: [WatchRoutePoint] {
        manager.result?.route ?? []
    }

    /// Distance and pace belong on any workout that measured distance, not only
    /// the ones that recorded a route — a treadmill session has both.
    private var showsDistance: Bool {
        manager.mode.isOutdoor || (manager.result?.distanceMeters ?? manager.distanceMeters) > 0
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

/// The recorded GPS route as a bare trace — no map tiles.
///
/// Deliberately not a `Map`: the wrist has no business pulling map imagery down
/// the moment a workout ends, and for a field session the tiles are not the
/// point. What the athlete wants to see is the shape of the ground they covered,
/// and an unadorned polyline shows the back-and-forth more honestly than a
/// street map does at that zoom. The phone still renders the full map version
/// once the workout syncs across.
struct WatchRouteTrace: View {
    let points: [WatchRoutePoint]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let projected = Self.project(points, into: geo.size)
                guard let first = projected.first else { return }
                path.move(to: first)
                for point in projected.dropFirst() { path.addLine(to: point) }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    /// Fit the route into `size`, preserving its true proportions.
    ///
    /// All the arithmetic is in `Double` rather than `CGFloat` on purpose:
    /// `CGFloat` is a `Float` on watchOS, and coordinates differing in their
    /// sixth decimal place — a couple of metres apart, which is most of a field
    /// session — collapse into the same value at single precision.
    private static func project(_ points: [WatchRoutePoint], into size: CGSize) -> [CGPoint] {
        guard points.count > 1 else { return [] }

        // A degree of longitude is shorter than a degree of latitude everywhere
        // but the equator. Without this correction an east-west shuttle draws
        // wider than the identical run done north-south, and the pitch comes out
        // sheared.
        let meanLat = points.reduce(0.0) { $0 + $1.lat } / Double(points.count)
        let lngScale = max(0.1, cos(meanLat * .pi / 180))

        let xs = points.map { $0.lng * lngScale }
        let ys = points.map { $0.lat }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return [] }

        // Floors keep a near-stationary route from being magnified into noise,
        // and keep the divisions below away from zero.
        let spanX = max(maxX - minX, 1e-7)
        let spanY = max(maxY - minY, 1e-7)

        let width = Double(size.width), height = Double(size.height)
        let inset = 6.0
        guard width > inset * 2, height > inset * 2 else { return [] }

        // One scale for both axes, so the trace keeps the shape of the ground
        // covered instead of being stretched to fill the box.
        let scale = min((width - inset * 2) / spanX, (height - inset * 2) / spanY)
        let offsetX = (width - spanX * scale) / 2
        let offsetY = (height - spanY * scale) / 2

        return points.map { point in
            let x = (point.lng * lngScale - minX) * scale + offsetX
            // Latitude climbs north; screen coordinates climb south.
            let y = height - ((point.lat - minY) * scale + offsetY)
            return CGPoint(x: x, y: y)
        }
    }
}
