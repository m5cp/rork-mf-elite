//
//  ParentReportView.swift
//  MFElite
//
//  The monthly progress summary written for parents.
//

import SwiftUI
import SwiftData

/// Navigation route to the parent report.
struct ParentReportRoute: Hashable {}

struct ParentReportView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var players: [PlayerState]
    @Query private var progress: [DrillProgress]
    @Query(sort: \CombineTest.sortIndex) private var combineTests: [CombineTest]
    @Query private var combineResults: [CombineResult]
    @Query(sort: \GameIQLesson.sortIndex) private var gameIQLessons: [GameIQLesson]

    @State private var profile = PlayerProfileStore.shared

    private var viewModel: ParentReportViewModel {
        ParentReportViewModel(
            disciplines: disciplines,
            xp: players.first?.xp ?? 0,
            streak: players.first?.streak ?? 0,
            lastTrainedDate: players.first?.lastTrainedDate,
            masteredDrillIDs: Set(progress.filter { $0.isMastered }.map { $0.drillID }),
            sessionsLogged: progress.reduce(0) { $0 + $1.passesLogged }
        )
    }

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                pillars(vm)
                narrative(vm)
                attendance(vm)
                combineSection
                gameIQReportSection
                coachNote(vm)
                ctas
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ReportCardRoute.self) { _ in
            ReportCardView()
        }
    }

    // MARK: - 1. Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Monthly Progress Report")
            Text("\(PlayerProfileStore.shared.displayName) is developing")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s8)
            Text("A snapshot of this month's training, discipline, and growth.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .padding(.top, DS.Spacing.s8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - 2. Pillar cards

    private func pillars(_ vm: ParentReportViewModel) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: DS.Spacing.s12),
            GridItem(.flexible(), spacing: DS.Spacing.s12)
        ]
        return LazyVGrid(columns: columns, spacing: DS.Spacing.s12) {
            pillarCard(label: "Consistency", value: "\(vm.consistencyPercent)%",
                       caption: "of training days completed")
            pillarCard(label: "Discipline", value: "\(vm.drillsMastered)",
                       caption: "drills mastered this month")
            pillarCard(label: "Accountability", value: "\(vm.sessionsLogged)",
                       caption: "sessions logged honestly")
            pillarCard(label: "Growth", value: "+\(vm.newCertifications)",
                       caption: "new certifications earned")
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func pillarCard(label: String, value: String, caption: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: label)
                Text(value)
                    .font(DS.Typography.num(size: 36))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s8)
                Text(caption)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .padding(.top, DS.Spacing.s4)
            }
        }
    }

    // MARK: - 3. Development narrative

    private func narrative(_ vm: ParentReportViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Development Narrative")
            Text(narrativeText(vm))
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .padding(.top, DS.Spacing.s12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    /// A development narrative built from the player's real progress this month,
    /// so a brand-new player never sees fabricated streaks or certifications.
    private func narrativeText(_ vm: ParentReportViewModel) -> String {
        let name = PlayerProfileStore.shared.displayName
        guard vm.sessionsLogged > 0 || vm.drillsMastered > 0 || vm.streak > 0 else {
            return "\(name) has just joined the academy. As training sessions are logged, this report will track consistency, drills mastered, and the certifications earned along the way."
        }

        var lines: [String] = []
        if vm.drillsMastered > 0 {
            let drillWord = vm.drillsMastered == 1 ? "drill" : "drills"
            lines.append("\(name) has mastered \(vm.drillsMastered) \(drillWord) this month, showing real close-control development.")
        } else {
            lines.append("\(name) has shown consistent effort across the training pathways this month.")
        }
        if let cert = vm.certifiedCategoryNames.first {
            lines.append("The \(cert) certification demonstrates strong progress.")
        }
        if vm.streak > 0 {
            let dayWord = vm.streak == 1 ? "day" : "days"
            lines.append("A \(vm.streak)-\(dayWord) training streak shows growing commitment to daily practice.")
        }
        return lines.joined(separator: " ")
    }

    // MARK: - 4. Attendance grid (8 weeks)

    private func attendance(_ vm: ParentReportViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Attendance · Last 8 Weeks")

            HStack(spacing: 6) {
                ForEach(Array(vm.weekdayInitials.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .style(.microSm)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, DS.Spacing.s12)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(vm.attendanceDays) { day in
                    dayCell(day)
                }
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    @ViewBuilder
    private func dayCell(_ day: ActivityDay) -> some View {
        switch day.state {
        case .trained:
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(height: 24)
        case .notTrained:
            RoundedRectangle(cornerRadius: 6)
                .fill(DS.Colors.Bg.raised)
                .frame(height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )
        case .future:
            RoundedRectangle(cornerRadius: 6)
                .fill(DS.Colors.Bg.raised.opacity(0.5))
                .frame(height: 24)
        case .todayPending:
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .frame(height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            DS.Colors.Line.strong,
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                        )
                )
        }
    }

    // MARK: - Combine section

    /// Tests that have at least one recorded result, in sort order.
    private var combineTestsWithData: [CombineTest] {
        combineTests.filter { test in
            combineResults.contains { $0.testID == test.id }
        }
    }

    @ViewBuilder
    private var combineSection: some View {
        if !combineTestsWithData.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "MF Combine")

                VStack(spacing: 0) {
                    ForEach(Array(combineTestsWithData.enumerated()), id: \.element.id) { index, test in
                        combineRow(test)
                        if index != combineTestsWithData.count - 1 {
                            Hairline()
                        }
                    }
                }
                .padding(.top, DS.Spacing.s8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24 + 4)
        }
    }

    private func combineRow(_ test: CombineTest) -> some View {
        let latest = CombineStats.latest(test.id, results: combineResults)
        let best = CombineStats.personalBest(test, results: combineResults)
        let trend = CombineStats.recentTrend(test, results: combineResults)
        let tiers = combineTierCaption(test, value: latest?.value)
        return VStack(alignment: .leading, spacing: DS.Spacing.s4) {
            HStack(spacing: DS.Spacing.s8) {
                Text(test.name)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.primary)
                if let trend {
                    Image(systemName: combineTrendSymbol(trend))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(trend.tint)
                }
                Spacer(minLength: DS.Spacing.s8)
                if let latest {
                    Text("\(CombineFormat.value(latest.value, unit: test.unit)) \(test.unit)")
                        .font(DS.Typography.num(size: 16))
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
            }
            HStack(spacing: DS.Spacing.s8) {
                if let latest {
                    Text("Latest \(CombineFormat.relative(latest.recordedAt))")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
                if let best {
                    Text("· Best \(CombineFormat.value(best, unit: test.unit))")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
            }
            if let tiers {
                Text(tiers)
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DS.Spacing.s12)
    }

    private func combineTierCaption(_ test: CombineTest, value: Double?) -> String? {
        guard let value,
              let age = profile.age,
              let male = CombineBenchmarks.shared.standing(testID: test.id, value: value, age: age, female: false),
              let female = CombineBenchmarks.shared.standing(testID: test.id, value: value, age: age, female: true)
        else { return nil }
        return "M: \(male.tier.label) · W: \(female.tier.label)"
    }

    private func combineTrendSymbol(_ delta: CombineDelta) -> String {
        switch delta {
        case .improved: return "arrow.up"
        case .same:     return "minus"
        case .declined: return "arrow.down"
        }
    }

    // MARK: - Game IQ section

    @ViewBuilder
    private var gameIQReportSection: some View {
        if !gameIQLessons.isEmpty {
            let completed = gameIQLessons.filter { $0.isCompleted }.count
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Game IQ")
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s8) {
                    Text("Lessons completed")
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Spacer(minLength: DS.Spacing.s8)
                    Text("\(completed) of \(gameIQLessons.count)")
                        .font(DS.Typography.num(size: 16))
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .padding(.top, DS.Spacing.s12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24 + 4)
        }
    }

    // MARK: - 5. Coach note

    private func coachNote(_ vm: ParentReportViewModel) -> some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Coach Note")
                Text("\u{201C}Keep training every day. The discipline you build now will define the player you become.\u{201D}")
                    .font(DS.Typography.callout)
                    .italic()
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .padding(.top, DS.Spacing.s12 - 2)
                Text("\u{2014} Coach Matteo Finazzi")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .padding(.top, DS.Spacing.s8)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - 6. CTAs

    private var ctas: some View {
        VStack(spacing: DS.Spacing.s12) {
            NavigationLink(value: ReportCardRoute()) {
                ZStack {
                    Text("View academy report card")
                        .font(.system(size: 17, weight: .bold))
                        .tracking(0.1)
                        .foregroundStyle(DS.Colors.Ground.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                .pillLightElevation()
            }
            .buttonStyle(PressableButtonStyle())

            Text("Sent to parents on the 1st of every month")
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }
}

#Preview {
    NavigationStack {
        ParentReportView()
            .preferredColorScheme(.dark)
            .modelContainer(for: [
                Discipline.self, Category.self, MasteryLevel.self,
                Drill.self, DrillProgress.self, PlayerState.self
            ])
    }
}
