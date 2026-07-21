//
//  DayDetailView.swift
//  MFElite
//
//  A single day's training detail: full rings, totals, and the ordered list of
//  logged drills, grouped under their routine/workout when chained.
//

import SwiftUI
import SwiftData

struct DayDetailView: View {
    let date: Date

    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var sessions: [SessionLogEntry]
    @Query(sort: \WorkoutRecord.startedAt, order: .reverse) private var workouts: [WorkoutRecord]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWorkout: WorkoutRecord?

    private let calendar: Calendar = .current

    /// disciplineID → mark.
    private var markByDiscipline: [String: String] {
        Dictionary(disciplines.map { ($0.id, $0.mark) }, uniquingKeysWith: { a, _ in a })
    }

    private var dayEntries: [SessionLogEntry] {
        sessions
            .filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
            .sorted { $0.completedAt < $1.completedAt }
    }

    private var rings: DailyRings {
        DailyRings.make(from: sessions, workouts: workouts, on: date, calendar: calendar)
    }

    /// Watch workouts logged on this day (newest first).
    private var dayWorkouts: [WorkoutRecord] {
        workouts.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
    }

    /// Total minutes including both drill sessions and watch workouts.
    private var totalMinutes: Int {
        let drillSec = dayEntries.reduce(0) { $0 + $1.durationSec }
        let workoutSec = dayWorkouts.reduce(0) { $0 + $1.durationSec }
        return Int((Double(drillSec + workoutSec) / 60).rounded())
    }

    private var totalXP: Int {
        dayEntries.reduce(0) { $0 + $1.xpEarned } + dayWorkouts.reduce(0) { $0 + $1.xpEarned }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                grabber
                title
                ringsBlock
                totalsRow
                if !dayWorkouts.isEmpty {
                    workoutsSection
                }
                if dayEntries.isEmpty {
                    if dayWorkouts.isEmpty { emptyState }
                } else {
                    sessionGroups
                }
            }
            .padding(.bottom, 40)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationDestination(item: $selectedWorkout) { workout in
            WorkoutDetailView(record: workout)
        }
    }

    // MARK: - Watch workouts

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Workouts")
            ForEach(dayWorkouts) { workout in
                Button {
                    selectedWorkout = workout
                } label: {
                    WorkoutCardView(record: workout)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    private var grabber: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .frame(width: 32, height: 32)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(Circle())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
            Eyebrow(text: weekdayLabel)
            Text(dateLabel)
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s8)
    }

    private var weekdayLabel: String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEEE"
        return fmt.string(from: date)
    }

    private var dateLabel: String {
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: date)
    }

    private var ringsBlock: some View {
        HStack {
            Spacer()
            DayRingsView(rings: rings, size: 130)
            Spacer()
        }
        .padding(.top, DS.Spacing.s32)
    }

    private var totalsRow: some View {
        HStack(spacing: 0) {
            totalCell("\(totalMinutes)", "Minutes")
            divider
            totalCell("\(dayEntries.count)", "Drills")
            divider
            totalCell("\(totalXP)", "XP")
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    private func totalCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 24))
                .tracking(-1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Eyebrow(text: label)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(DS.Colors.Line.hairline).frame(width: 1, height: 40)
    }

    // MARK: - Session list grouped by source

    private var sessionGroups: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s20) {
            ForEach(groupedEntries) { group in
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    if let header = group.header {
                        Eyebrow(text: header)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                            entryRow(entry)
                            if index != group.entries.count - 1 {
                                Hairline()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    private func entryRow(_ entry: SessionLogEntry) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            Text(timeLabel(entry.completedAt))
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .frame(width: 56, alignment: .leading)

            DisciplineMark(kind: markByDiscipline[entry.disciplineID] ?? "square", size: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.drillTitle)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if entry.source != SessionSource.single.rawValue, let name = entry.sourceName {
                    Text(name)
                        .style(.microSm)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
                if entry.sourceName == "Match Day" {
                    Text("MATCH DAY")
                        .style(.microSm)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
                if !entry.completedFully {
                    Text("logged early")
                        .style(.microSm)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
            }

            Spacer(minLength: DS.Spacing.s8)

            Text(durationLabel(entry.durationSec))
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .padding(.vertical, DS.Spacing.s12)
    }

    private func timeLabel(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }

    private func durationLabel(_ sec: Int) -> String {
        let minutes = sec / 60
        let seconds = sec % 60
        if minutes > 0 { return "\(minutes)m" }
        return "\(seconds)s"
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.s8) {
            Text("No training logged")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.secondary)
            Text("Rest day — or time to get a touch in.")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.s40)
    }

    /// Groups consecutive entries that share the same routine/workout name.
    private var groupedEntries: [EntryGroup] {
        var groups: [EntryGroup] = []
        for entry in dayEntries {
            let header: String? = {
                guard entry.source != SessionSource.single.rawValue, let name = entry.sourceName else { return nil }
                let label = entry.source == SessionSource.workout.rawValue ? "Workout" : "Routine"
                return "\(label) — \(name)"
            }()
            if let last = groups.last, last.header == header, header != nil {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append(EntryGroup(id: groups.count, header: header, entries: [entry]))
            }
        }
        return groups
    }

    private struct EntryGroup: Identifiable {
        let id: Int
        let header: String?
        var entries: [SessionLogEntry]
    }
}
