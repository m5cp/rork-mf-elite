//
//  ProgressTabView.swift
//  MFElite
//
//  Tab 3 — the player's training analytics dashboard.
//

import SwiftUI
import SwiftData

/// Navigation route to the academy progression overview.
struct AcademyProgressionRoute: Hashable {}

/// A date wrapped for use as a `.sheet(item:)` selection.
struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
}

struct ProgressTabView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var progress: [DrillProgress]
    @Query private var sessions: [SessionLogEntry]
    @Query private var players: [PlayerState]
    @Query private var combineResults: [CombineResult]
    @Query(sort: \CombineTest.sortIndex) private var combineTests: [CombineTest]

    @State private var selectedDay: IdentifiableDate?
    @State private var gameCenter = GameCenterService.shared
    @State private var profile = PlayerProfileStore.shared

    private var viewModel: ProgressDashboardViewModel {
        ProgressDashboardViewModel(disciplines: disciplines, sessions: sessions, progress: progress)
    }

    var body: some View {
        NavigationStack {
            let vm = viewModel
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    todayRings(vm)
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        weeklyRecap
                        weekOverview(vm)
                        if vm.hasReflections {
                            reflections(vm)
                        }
                        monthlyTrend(vm)
                        intensity(vm)
                        disciplineBreakdown(vm)
                    }
                    combineEntry
                    combineTrendStrip
                    proofOfProgressEntry
                    quickLinks
                }
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .navigationDestination(for: WeeklyRoute.self) { _ in HistoryCalendarView() }
            .navigationDestination(for: AcademyProgressionRoute.self) { _ in AcademyProgressionView() }
            .navigationDestination(for: CombineRoute.self) { _ in CombineView() }
            .navigationDestination(for: FriendsLeaderboardRoute.self) { _ in FriendsLeaderboardView() }
            .navigationDestination(for: ProofOfProgressRoute.self) { _ in ProofOfProgressView() }
            .sheet(item: $selectedDay) { wrapped in
                DayDetailView(date: wrapped.date)
                    .presentationDetents([.large])
            }
        }
    }

    // MARK: - Weekly recap

    @ViewBuilder
    private var weeklyRecap: some View {
        let recap = WeekRecap(
            sessions: sessions,
            currentXP: players.first?.xp ?? 0,
            currentStreak: players.first?.streak ?? 0
        )
        if recap.hasActivity {
            WeeklyRecapSection(recap: recap, playerName: profile.displayName)
        }
    }

    // MARK: - Today's rings

    private func todayRings(_ vm: ProgressDashboardViewModel) -> some View {
        let rings = vm.todayRings
        return Card {
            HStack(spacing: DS.Spacing.s20) {
                DayRingsView(rings: rings, size: 90)

                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Today")
                    ringCountRow(tint: Color.white, label: "Train", value: "\(rings.trainMinutes)", unit: "/ \(DailyRings.trainGoalMinutes) min")
                    ringCountRow(tint: Color.white.opacity(0.68), label: "Drills", value: "\(rings.drillCount)", unit: "/ \(DailyRings.drillGoal)")
                    ringCountRow(tint: Color.white.opacity(0.42), label: "Mind", value: "\(rings.mindCount)", unit: "/ \(DailyRings.mindGoal)")
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private func ringCountRow(tint: Color, label: String, value: String, unit: String) -> some View {
        HStack(spacing: DS.Spacing.s8) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(label)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.secondary)
            Spacer(minLength: DS.Spacing.s8)
            Text(value)
                .font(DS.Typography.num(size: 16))
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(unit)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Eyebrow(text: "No training yet")
                Text("Log your first drill and your weekly stats, trends, and rings will start filling in here.")
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - 1. Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Progress")
            Text("Training")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s64)
    }

    // MARK: - 2. This week overview

    private func weekOverview(_ vm: ProgressDashboardViewModel) -> some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Eyebrow(text: "This Week")

                HStack(spacing: 0) {
                    overviewStat("Sessions", "\(vm.sessionsThisWeek)")
                    overviewDivider
                    overviewStat("XP Earned", "\(vm.xpThisWeek)")
                    overviewDivider
                    overviewStat("Mastered", "\(vm.masteredThisWeek)")
                }

                ringStrip(vm)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    /// A 7-day Mon–Sun strip of mini ring clusters; today is outlined and any
    /// day is tappable to open its detail.
    private func ringStrip(_ vm: ProgressDashboardViewModel) -> some View {
        HStack(spacing: 6) {
            ForEach(vm.ringStripDays) { day in
                Button {
                    selectedDay = IdentifiableDate(date: day.date)
                } label: {
                    VStack(spacing: DS.Spacing.s8) {
                        DayRingsView(rings: day.rings, size: 34, showCheckmarks: false)
                            .opacity(day.isFuture ? 0.35 : 1)
                            .overlay {
                                if day.isToday {
                                    Circle().stroke(DS.Colors.Line.strong, lineWidth: 1.5)
                                }
                            }
                        Text(day.initial)
                            .style(.microSm)
                            .foregroundStyle(day.isToday ? DS.Colors.Ink.secondary : DS.Colors.Ink.quaternary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(day.isFuture)
            }
        }
        .padding(.top, DS.Spacing.s8)
    }

    private func overviewStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 28))
                .tracking(-1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Eyebrow(text: label)
        }
        .frame(maxWidth: .infinity)
    }

    private var overviewDivider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 40)
    }

    private func weekChart(_ vm: ProgressDashboardViewModel) -> some View {
        let maxCount = vm.maxDayCount
        return VStack(spacing: DS.Spacing.s8) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(vm.dayBars) { bar in
                    let height: CGFloat = bar.count > 0
                        ? max(8, 60 * CGFloat(bar.count) / CGFloat(maxCount))
                        : 4
                    RoundedRectangle(cornerRadius: 3)
                        .fill(bar.count > 0 ? Color.white : DS.Colors.Bg.raised)
                        .frame(height: height)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            if bar.isToday {
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(DS.Colors.Line.strong, lineWidth: 1.5)
                            }
                        }
                }
            }
            .frame(height: 60, alignment: .bottom)

            HStack(spacing: 6) {
                ForEach(vm.dayBars) { bar in
                    Text(bar.initial)
                        .style(.microSm)
                        .foregroundStyle(bar.isToday ? DS.Colors.Ink.secondary : DS.Colors.Ink.quaternary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, DS.Spacing.s8)
    }

    // MARK: - Reflections

    private func reflections(_ vm: ProgressDashboardViewModel) -> some View {
        let notes = vm.recentReflections()
        return Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                HStack(alignment: .firstTextBaseline) {
                    Eyebrow(text: "Reflections")
                    Spacer()
                    if let avg = vm.averageFeltRating {
                        HStack(spacing: DS.Spacing.s4) {
                            Text(String(format: "%.1f", avg))
                                .font(DS.Typography.num(size: 16))
                                .foregroundStyle(DS.Colors.Ink.primary)
                            Text("/ 5 felt")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                        }
                    }
                }

                Text(vm.feltTrendLabel)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.secondary)

                if notes.isEmpty {
                    Text("Add a note at your next check-in and it’ll show up here.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(notes.enumerated()), id: \.element.id) { idx, note in
                            reflectionRow(note)
                            if idx != notes.count - 1 { Hairline() }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private func reflectionRow(_ note: ReflectionNote) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
            HStack(spacing: DS.Spacing.s8) {
                Text(note.drillTitle)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .lineLimit(1)
                Spacer(minLength: DS.Spacing.s8)
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(i < note.rating ? Color.white : DS.Colors.Line.subtle)
                        .frame(width: 5, height: 5)
                }
            }
            Text("“\(note.note)”")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DS.Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 3. Monthly trend

    private func monthlyTrend(_ vm: ProgressDashboardViewModel) -> some View {
        let maxSessions = vm.maxWeekSessions
        return VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Last 4 Weeks")

            VStack(spacing: DS.Spacing.s12) {
                ForEach(vm.weekBars) { week in
                    HStack(spacing: DS.Spacing.s12) {
                        Text(week.label)
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .frame(width: 36, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DS.Colors.Bg.raised)
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(
                                        width: week.sessions > 0
                                            ? max(8, geo.size.width * CGFloat(week.sessions) / CGFloat(maxSessions))
                                            : 0,
                                        height: 8
                                    )
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 8)

                        Text("\(week.sessions)")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32 - 4)
    }

    // MARK: - 4. Intensity

    private func intensity(_ vm: ProgressDashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Intensity")

            Text("Average \(vm.averageDrillsPerSession) drills per session this week")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.secondary)

            HStack(spacing: DS.Spacing.s8) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < vm.intensityLevel ? Color.white : Color.clear)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle().stroke(
                                index < vm.intensityLevel ? Color.clear : DS.Colors.Line.subtle,
                                lineWidth: 1
                            )
                        )
                }
            }

            Text(vm.intensityLabel)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32 - 4)
    }

    // MARK: - 5. Discipline breakdown

    private func disciplineBreakdown(_ vm: ProgressDashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "By Discipline")
                .padding(.bottom, DS.Spacing.s4)

            let stats = vm.disciplineStats
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                HStack(spacing: DS.Spacing.s12) {
                    DisciplineMark(kind: stat.mark, size: 18)
                    Text(stat.name)
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Spacer(minLength: DS.Spacing.s8)
                    Text("\(stat.sessions)")
                        .font(DS.Typography.num(size: 16))
                        .tracking(-0.5)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
                .padding(.vertical, DS.Spacing.s12)

                if index != stats.count - 1 {
                    Hairline()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32 - 4)
    }

    // MARK: - MF Combine entry

    private var combineEntry: some View {
        let lastDate = CombineStats.lastCombineDate(combineResults)
        return NavigationLink(value: CombineRoute()) {
            Card {
                HStack(spacing: DS.Spacing.s16) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(width: 44, height: 44)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                        Eyebrow(text: "MF Combine")
                        Text("Test your baseline")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text(lastDate == nil
                             ? "8 tests · about 30 minutes"
                             : "Last combine \(CombineFormat.relative(lastDate!))")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32 - 4)
    }

    // MARK: - MF Combine trend strip

    /// A compact row of all 8 tests, each with a tiny arrow showing the latest
    /// result versus the previous one (lowerIsBetter-aware). Hidden until at
    /// least one result exists.
    @ViewBuilder
    private var combineTrendStrip: some View {
        if !combineResults.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                Eyebrow(text: "Combine Trends")

                let columns = Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.s8), count: 4)
                LazyVGrid(columns: columns, spacing: DS.Spacing.s12) {
                    ForEach(combineTests) { test in
                        combineTrendCell(test)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s32 - 4)
        }
    }

    private func combineTrendCell(_ test: CombineTest) -> some View {
        let best = CombineStats.personalBest(test, results: combineResults)
        let trend = CombineStats.recentTrend(test, results: combineResults)
        return VStack(spacing: DS.Spacing.s4) {
            HStack(spacing: 3) {
                Text(best.map { CombineFormat.value($0, unit: test.unit) } ?? "—")
                    .font(DS.Typography.num(size: 17))
                    .foregroundStyle(DS.Colors.Ink.primary)
                if let trend {
                    Image(systemName: trendSymbol(trend))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(trend.tint)
                }
            }
            Text(test.name)
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s12)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
    }

    private func trendSymbol(_ delta: CombineDelta) -> String {
        switch delta {
        case .improved: return "arrow.up"
        case .same:     return "minus"
        case .declined: return "arrow.down"
        }
    }

    // MARK: - Proof of Progress entry

    /// Entry to the Proof of Progress dashboard, shown once any combine result
    /// exists so there's something to prove.
    @ViewBuilder
    private var proofOfProgressEntry: some View {
        if !combineResults.isEmpty {
            NavigationLink(value: ProofOfProgressRoute()) {
                Card {
                    HStack(spacing: DS.Spacing.s16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(width: 44, height: 44)
                            .background(DS.Colors.Bg.raised)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                            Eyebrow(text: "Proof of Progress")
                            Text("See how far you've come")
                                .style(.title3)
                                .foregroundStyle(DS.Colors.Ink.primary)
                            Text("Every PB and tier you've climbed")
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                }
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s32 - 4)
        }
    }

    // MARK: - 6. Quick links

    private var quickLinks: some View {
        VStack(spacing: 0) {
            NavigationLink(value: WeeklyRoute()) {
                QuickLinkRow(icon: "calendar", label: "History", isLast: false)
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink(value: AcademyProgressionRoute()) {
                QuickLinkRow(icon: "chart.line.uptrend.xyaxis", label: "Academy progression", isLast: false)
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink(value: FriendsLeaderboardRoute()) {
                QuickLinkRow(
                    icon: "trophy",
                    label: "Leaderboards",
                    detail: gameCenter.isAuthenticated ? "See how you rank vs friends" : "Sign in to Game Center",
                    isLast: true
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32 - 4)
    }
}

// MARK: - QuickLinkRow

private struct QuickLinkRow: View {
    let icon: String
    let label: String
    var detail: String? = nil
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 40, height: 40)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    if let detail {
                        Text(detail)
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s16)
            .contentShape(Rectangle())

            if !isLast {
                Hairline()
            }
        }
    }
}

#Preview {
    ProgressTabView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [
            Discipline.self, Category.self, MasteryLevel.self,
            Drill.self, DrillProgress.self, PlayerState.self
        ])
}
