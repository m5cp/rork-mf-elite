import WidgetKit
import SwiftUI

// MARK: - Shared data

/// App Group identifier — must match both targets' entitlements.
private let appGroup = "group.app.rork.pgx8pb996dmcvbhdfnx8x"

private enum WidgetKey {
    static let streak = "widget.streak"
    static let xp = "widget.xp"
    static let rankNumeral = "widget.rankNumeral"
    static let rankTitle = "widget.rankTitle"
    static let goalsDone = "widget.goalsDone"
    static let goalsTotal = "widget.goalsTotal"
    static let trainedToday = "widget.trainedToday"
}

nonisolated struct MFEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let xp: Int
    let rankNumeral: String
    let rankTitle: String
    let goalsDone: Int
    let goalsTotal: Int
    let trainedToday: Bool

    static let placeholder = MFEntry(
        date: .now, streak: 12, xp: 8200, rankNumeral: "II", rankTitle: "Academy",
        goalsDone: 2, goalsTotal: 3, trainedToday: false
    )

    /// Read the latest snapshot the app wrote to the shared App Group.
    static func current() -> MFEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        let total = max(1, defaults?.integer(forKey: WidgetKey.goalsTotal) ?? 3)
        return MFEntry(
            date: .now,
            streak: defaults?.integer(forKey: WidgetKey.streak) ?? 0,
            xp: defaults?.integer(forKey: WidgetKey.xp) ?? 0,
            rankNumeral: defaults?.string(forKey: WidgetKey.rankNumeral) ?? "I",
            rankTitle: defaults?.string(forKey: WidgetKey.rankTitle) ?? "New Talent",
            goalsDone: defaults?.integer(forKey: WidgetKey.goalsDone) ?? 0,
            goalsTotal: total,
            trainedToday: defaults?.bool(forKey: WidgetKey.trainedToday) ?? false
        )
    }
}

nonisolated struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MFEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (MFEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MFEntry>) -> Void) {
        let entry = MFEntry.current()
        // Refresh after midnight so "trained today" / goals reset visually.
        let next = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600 * 6)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Colors

private extension Color {
    static let mfInk = Color.white
    static let mfMuted = Color.white.opacity(0.55)
    static let mfBg = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let mfCard = Color.white.opacity(0.08)
}

// MARK: - Views

private struct StreakBlock: View {
    let entry: MFEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("\(entry.streak)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(Color.mfInk)
            Text(entry.streak == 1 ? "DAY STREAK" : "DAY STREAK")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(Color.mfMuted)
        }
    }
}

private struct GoalsRing: View {
    let entry: MFEntry
    var progress: Double { Double(entry.goalsDone) / Double(max(1, entry.goalsTotal)) }
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.mfInk, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(entry.goalsDone)/\(entry.goalsTotal)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.mfInk)
        }
    }
}

private struct SmallWidgetView: View {
    let entry: MFEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StreakBlock(entry: entry)
            Spacer(minLength: 6)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("RANK \(entry.rankNumeral)")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.mfMuted)
                    Text(entry.rankTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.mfInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                GoalsRing(entry: entry).frame(width: 38, height: 38)
            }
        }
    }
}

private struct MediumWidgetView: View {
    let entry: MFEntry
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                StreakBlock(entry: entry)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 1) {
                    Text("RANK \(entry.rankNumeral) · \(entry.xp.formatted()) XP")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Color.mfMuted)
                    Text(entry.rankTitle)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color.mfInk)
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                GoalsRing(entry: entry).frame(width: 64, height: 64)
                Text(entry.trainedToday ? "Trained today" : "Train today")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.mfMuted)
            }
        }
    }
}

private struct AccessoryRectView: View {
    let entry: MFEntry
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").font(.system(size: 14, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(entry.streak) day streak")
                    .font(.system(size: 15, weight: .bold))
                Text("Goals \(entry.goalsDone)/\(entry.goalsTotal) · Rank \(entry.rankNumeral)")
                    .font(.system(size: 12))
            }
        }
    }
}

private struct AccessoryCircView: View {
    let entry: MFEntry
    var body: some View {
        Gauge(value: Double(entry.goalsDone), in: 0...Double(max(1, entry.goalsTotal))) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(entry.streak)")
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct MFEliteWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: MFEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectView(entry: entry)
        case .accessoryCircular:
            AccessoryCircView(entry: entry)
        case .accessoryInline:
            Text("🔥 \(entry.streak) · \(entry.goalsDone)/\(entry.goalsTotal) goals")
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct MFEliteWidget: Widget {
    let kind: String = "MFEliteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MFEliteWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.mfBg }
        }
        .configurationDisplayName("Training Status")
        .description("Your streak, today's goals, and rank at a glance.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryCircular, .accessoryInline
        ])
    }
}

#Preview(as: .systemSmall) {
    MFEliteWidget()
} timeline: {
    MFEntry.placeholder
}
