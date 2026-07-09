//
//  MFEliteWatchComplication.swift
//  MFEliteWatchComplication
//
//  Watch-face complication showing the player's current streak and today's
//  ring progress. Reads the latest snapshot the phone (or watch app) wrote
//  into the shared App Group — no WatchConnectivity session needed since
//  widget extensions run independently of the watch app process.
//

import WidgetKit
import SwiftUI

nonisolated struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, glance: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(StreakEntry(date: .now, glance: WatchShared.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = StreakEntry(date: .now, glance: WatchShared.load())
        // Refresh every 30 minutes; the phone also pushes immediately on change.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

nonisolated struct StreakEntry: TimelineEntry {
    let date: Date
    let glance: WatchGlanceData
}

struct MFEliteWatchComplication: Widget {
    let kind: String = "MFEliteWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("MF Elite Streak")
        .description("Your current streak and today's training rings.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct ComplicationView: View {
    let entry: StreakEntry

    var body: some View {
        switch families {
        case .accessoryCircular:
            circular
        case .accessoryInline:
            Label("\(entry.glance.streak)-day streak", systemImage: "flame.fill")
        default:
            rectangular
        }
    }

    @Environment(\.widgetFamily) private var families

    private var progress: Double {
        let g = entry.glance
        let total = g.trainGoalMinutes + g.drillGoal + g.mindGoal
        guard total > 0 else { return 0 }
        let done = min(g.trainMinutes, g.trainGoalMinutes) + min(g.drillCount, g.drillGoal) + min(g.mindCount, g.mindGoal)
        return Double(done) / Double(total)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Gauge(value: min(1, progress)) {
                Image(systemName: "flame.fill")
            } currentValueLabel: {
                Text("\(entry.glance.streak)")
            }
            .gaugeStyle(.accessoryCircular)
        }
        .containerBackground(.clear, for: .widget)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("\(entry.glance.streak)-day streak")
                    .font(.headline)
            }
            Text(entry.glance.sessionTitle)
                .font(.caption2)
                .lineLimit(1)
        }
        .containerBackground(.clear, for: .widget)
    }
}
