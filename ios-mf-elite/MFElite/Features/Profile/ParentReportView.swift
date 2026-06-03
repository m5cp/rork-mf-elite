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
                coachNote
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

    // MARK: - 5. Coach note

    private var coachNote: some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Coach Note")
                Text("Player One is progressing well through the Technical pathway. Focus next month on Tactical awareness — positioning and scanning will round out the development profile.")
                    .font(DS.Typography.callout)
                    .italic()
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .padding(.top, DS.Spacing.s12 - 2)
                Text("— Coach Williams")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .padding(.top, DS.Spacing.s12)
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
