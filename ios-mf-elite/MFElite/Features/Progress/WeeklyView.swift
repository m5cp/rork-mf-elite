//
//  WeeklyView.swift
//  MFElite
//
//  A detailed, day-by-day breakdown of the current training week.
//

import SwiftUI
import SwiftData

/// Navigation route to the weekly training breakdown.
struct WeeklyRoute: Hashable {}

struct WeeklyView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var progress: [DrillProgress]

    private var viewModel: ProgressDashboardViewModel {
        ProgressDashboardViewModel(disciplines: disciplines, progress: progress)
    }

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(vm)
                dayList(vm)
                summaryCard(vm)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private func header(_ vm: ProgressDashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Weekly Breakdown")
            Text(vm.weekRangeLabel)
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Day list

    private func dayList(_ vm: ProgressDashboardViewModel) -> some View {
        VStack(spacing: DS.Spacing.s12) {
            ForEach(vm.weekDays) { day in
                DayCard(day: day)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - Weekly summary

    private func summaryCard(_ vm: ProgressDashboardViewModel) -> some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Eyebrow(text: "Week Total")

                HStack(spacing: 0) {
                    summaryStat("\(vm.weeklyTotalSessions)", "Sessions")
                    summaryDivider
                    summaryStat("\(vm.weeklyTotalXP)", "XP")
                    summaryDivider
                    summaryStat("\(vm.weeklyTotalMastered)", "Mastered")
                }

                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    LevelPips(total: 7, done: vm.weeklyTrainedDays - 1, current: vm.weeklyTrainedDays)
                    Text("\(vm.weeklyTrainedDays) of 7 days trained")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    private func summaryStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 24))
                .tracking(-1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Eyebrow(text: label)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 40)
    }
}

// MARK: - DayCard

private struct DayCard: View {
    let day: WeekDay

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(day.name)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Spacer()
                    Text(day.shortDate)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }

                if day.drills.isEmpty {
                    Text(day.isFuture ? "Upcoming" : "Rest day")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                } else {
                    VStack(spacing: DS.Spacing.s8) {
                        ForEach(day.drills) { drill in
                            HStack(spacing: DS.Spacing.s12) {
                                DisciplineMark(kind: drill.mark, size: 14)
                                Text(drill.title)
                                    .style(.callout)
                                    .foregroundStyle(DS.Colors.Ink.secondary)
                                Spacer(minLength: DS.Spacing.s8)
                                Text("+\(drill.xp) XP")
                                    .style(.micro)
                                    .foregroundStyle(DS.Colors.Ink.tertiary)
                            }
                        }
                    }

                    Hairline()

                    Text("\(day.totalXP) XP earned")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WeeklyView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [
        Discipline.self, Category.self, MasteryLevel.self,
        Drill.self, DrillProgress.self, PlayerState.self
    ])
}
