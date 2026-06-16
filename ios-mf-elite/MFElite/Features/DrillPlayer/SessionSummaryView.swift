//
//  SessionSummaryView.swift
//  MFElite
//
//  End-of-session recap shown after the final drill of a queue is logged.
//

import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    let queue: TrainingQueue
    var onDone: () -> Void

    @Query private var players: [PlayerState]
    @Query private var sessionLog: [SessionLogEntry]
    @State private var reveal = false
    @State private var showCheckIn = false

    private var totalMinutes: Int {
        let secs = queue.completed.reduce(0) { $0 + $1.durationSec }
        return max(1, Int((Double(secs) / 60).rounded()))
    }

    private var totalXP: Int {
        queue.completed.reduce(0) { $0 + $1.xp }
    }

    private var streak: Int { players.first?.streak ?? 0 }

    // MARK: - Week-over-week trend

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private var currentMonday: Date {
        let cal = calendar
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysSinceMonday = (weekday - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
    }

    private func sessionCount(weeksAgo: Int) -> Int {
        let cal = calendar
        guard let start = cal.date(byAdding: .day, value: -7 * weeksAgo, to: currentMonday),
              let end = cal.date(byAdding: .day, value: 7, to: start) else { return 0 }
        return sessionLog.filter { $0.completedAt >= start && $0.completedAt < end }.count
    }

    /// A plain-language progress line shown when this week beats last, or as
    /// encouragement on the first sessions of a new week.
    private var trendLine: String? {
        let thisWeek = sessionCount(weeksAgo: 0)
        let lastWeek = sessionCount(weeksAgo: 1)
        if lastWeek > 0 && thisWeek > lastWeek {
            return "Trending up — \(thisWeek) sessions this week vs \(lastWeek) last week."
        }
        if lastWeek > 0 && thisWeek == lastWeek {
            return "Matching last week — \(thisWeek) sessions. One more pulls you ahead."
        }
        if thisWeek >= 1 {
            return "\(thisWeek) \(thisWeek == 1 ? "session" : "sessions") logged this week. Keep it rolling."
        }
        return nil
    }

    private var headline: String {
        switch queue.source {
        case .routine: return "Routine complete"
        case .workout: return "Workout complete"
        case .single:  return "Session complete"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 92, height: 92)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                    )
                    .scaleEffect(reveal ? 1 : 0)
                    .padding(.top, DS.Spacing.s64)

                Eyebrow(text: headline.uppercased())
                    .padding(.top, DS.Spacing.s24)

                if let name = queue.sourceName {
                    Text(name)
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .multilineTextAlignment(.center)
                        .padding(.top, DS.Spacing.s8)
                } else {
                    Text("Well trained.")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(.top, DS.Spacing.s8)
                }

                statsRow
                    .padding(.top, DS.Spacing.s32)

                if let trendLine {
                    trendCard(trendLine)
                        .padding(.top, DS.Spacing.s16)
                }

                drillList
                    .padding(.top, DS.Spacing.s24)

                SyncStatusChip()
                    .padding(.top, DS.Spacing.s24)

                PrimaryButton(label: "Done") { onDone() }
                    .padding(.top, DS.Spacing.s20)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Colors.Bg.base)
        .sessionCheckIn(isPresented: $showCheckIn, drillCount: queue.completed.count)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(DS.Motion.celebrationSpring) { reveal = true }
            if !queue.completed.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showCheckIn = true
                }
            }
        }
    }

    private func trendCard(_ text: String) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(text)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    private var statsRow: some View {
        HStack(spacing: DS.Spacing.s12) {
            summaryTile(value: "\(queue.completed.count)", label: "Drills")
            summaryTile(value: "\(totalMinutes)", label: "Minutes")
            summaryTile(value: "+\(totalXP)", label: "XP")
            summaryTile(value: "\(streak)", label: "Streak")
        }
    }

    private func summaryTile(value: String, label: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 24))
                .tracking(-0.6)
                .foregroundStyle(DS.Colors.Ink.primary)
            Eyebrow(text: label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s16)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var drillList: some View {
        VStack(spacing: 0) {
            ForEach(Array(queue.completed.enumerated()), id: \.element.id) { idx, item in
                HStack(spacing: DS.Spacing.s12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    DisciplineMark(kind: item.disciplineMark, size: 14)
                    Text(item.title)
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, DS.Spacing.s12)

                if idx != queue.completed.count - 1 {
                    Hairline()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s16)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}
