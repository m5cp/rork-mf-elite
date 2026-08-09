//
//  WorkoutCardView.swift
//  MFElite
//
//  Apple Fitness-style cards for a synced Apple Watch workout: a compact card
//  with the route-map thumbnail and headline stats, and a full detail view with
//  a larger interactive route map. Shared by the calendar day view and Progress.
//

import SwiftUI
import MapKit

/// Shared formatting for workout stats (distance/pace honour the unit setting).
enum WorkoutFormat {
    static func distance(_ meters: Double, useMiles: Bool) -> String {
        let value = useMiles ? meters / 1609.344 : meters / 1000
        return String(format: "%.2f %@", value, useMiles ? "mi" : "km")
    }

    static func duration(_ sec: Int) -> String {
        let h = sec / 3600, m = (sec % 3600) / 60, s = sec % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func pace(meters: Double, sec: Int, useMiles: Bool) -> String {
        guard meters > 20, sec > 0 else { return "--:--" }
        let secPerKm = Double(sec) / (meters / 1000)
        let secPerUnit = useMiles ? secPerKm * 1.609344 : secPerKm
        let m = Int(secPerUnit) / 60, s = Int(secPerUnit) % 60
        return String(format: "%d:%02d/%@", m, s, useMiles ? "mi" : "km")
    }
}

/// A compact workout card with a route-map thumbnail (outdoor) and headline stats.
struct WorkoutCardView: View {
    let record: WorkoutRecord
    @AppStorage("MF_RUN_UNIT_MILES") private var useMiles = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let image = WorkoutRouteRenderer.image(named: record.routeImageName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                HStack(spacing: DS.Spacing.s8) {
                    Image(systemName: record.mode.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: record.mode.accentHex))
                    Text(record.mode.displayName)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Spacer(minLength: 0)
                    Text(record.startedAt, format: .dateTime.hour().minute())
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
                HStack(spacing: DS.Spacing.s16) {
                    // Distance is shown on the strength of there being distance,
                    // not on the mode recording a route: a treadmill or elliptical
                    // workout measures distance and used to have it hidden.
                    if record.distanceMeters > 0 {
                        stat(WorkoutFormat.distance(record.distanceMeters, useMiles: useMiles), "Distance")
                    }
                    stat(WorkoutFormat.duration(record.durationSec), "Time")
                    if record.distanceMeters > 0 {
                        stat(WorkoutFormat.pace(meters: record.distanceMeters, sec: record.durationSec, useMiles: useMiles), "Pace")
                    }
                    stat("\(Int(record.activeCalories))", "Cal")
                }
            }
            .padding(DS.Spacing.s16)
        }
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(DS.Typography.num(size: 16))
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(label.uppercased())
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
    }
}

/// Full workout detail: a larger interactive route map plus all stats.
struct WorkoutDetailView: View {
    let record: WorkoutRecord
    @AppStorage("MF_RUN_UNIT_MILES") private var useMiles = true
    @Environment(\.dismiss) private var dismiss

    private var coordinates: [CLLocationCoordinate2D] {
        record.routePoints.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                if coordinates.count > 1 {
                    map
                } else if let image = WorkoutRouteRenderer.image(named: record.routeImageName) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                }

                statsGrid
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle(record.mode.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var map: some View {
        Map(initialPosition: .region(region)) {
            MapPolyline(coordinates: coordinates)
                .stroke(Color(hex: record.mode.accentHex), lineWidth: 6)
            if let start = coordinates.first {
                Marker("Start", systemImage: "flag.fill", coordinate: start).tint(.green)
            }
            if let end = coordinates.last {
                Marker("Finish", systemImage: "flag.checkered", coordinate: end).tint(.red)
            }
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private var region: MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                      span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLng = first.longitude, maxLng = first.longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        // Matches `WorkoutRouteRenderer.minimumSpan`: the old 0.003° floor was
        // about 330 m, so a session worked entirely inside a soccer pitch opened
        // zoomed out far enough that the ground covered read as a smudge. The
        // athlete can still pinch out; they could not pinch in past the floor.
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.4, 0.0006),
                                   longitudeDelta: max((maxLng - minLng) * 1.4, 0.0006))
        )
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.s12) {
            if record.distanceMeters > 0 {
                statCard(WorkoutFormat.distance(record.distanceMeters, useMiles: useMiles), "Distance")
                statCard(WorkoutFormat.pace(meters: record.distanceMeters, sec: record.durationSec, useMiles: useMiles), "Avg pace")
            }
            statCard(WorkoutFormat.duration(record.durationSec), "Time")
            statCard("\(Int(record.activeCalories))", "Active calories")
            if record.maxHeartRate > 0 {
                statCard("\(record.avgHeartRate) bpm", "Avg heart rate")
                statCard("\(record.maxHeartRate) bpm", "Max heart rate")
            }
        }
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        Card(padding: DS.Spacing.s16) {
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(value)
                    .style(.title2)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(label.uppercased())
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
    }
}
