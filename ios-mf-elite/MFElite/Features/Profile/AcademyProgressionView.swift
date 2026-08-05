//
//  AcademyProgressionView.swift
//  MFElite
//
//  The rank timeline, next-rank progress, skill mastery, and development milestones.
//

import SwiftUI
import SwiftData

/// Navigation route to the academy progression screen.
struct ProgressionRoute: Hashable {}

struct AcademyProgressionView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var players: [PlayerState]
    @Query private var progress: [DrillProgress]
    @Environment(SubscriptionService.self) private var subscription
    @State private var ballonDor = BallonDorStore.shared

    private var totalCategories: Int {
        disciplines.reduce(0) { $0 + $1.categories.count }
    }

    private var viewModel: AcademyProgressionViewModel {
        AcademyProgressionViewModel(
            disciplines: disciplines,
            xp: players.first?.xp ?? 0,
            rankXP: players.first?.rankXP ?? 0,
            streak: players.first?.streak ?? 0,
            streakPB: players.first?.streakPB ?? 0,
            masteredDrillIDs: Set(progress.filter { $0.isMastered }.map { $0.drillID }),
            loggedDrillIDs: Set(progress.filter { $0.passesLogged > 0 }.map { $0.drillID })
        )
    }

    var body: some View {
        let vm = viewModel
        let meets = BallonDor.meetsRequirements(xp: vm.xp, certCount: vm.certCount, totalCategories: totalCategories)
        let bdState = ballonDor.state(meetsRequirements: meets)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(vm)
                nextRankCard(vm)
                timelineSection(vm, bdState: bdState)
                skillMasterySection(vm)
                milestonesSection(vm)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { ballonDor.recordRequestIfNeeded(meets: meets, xp: vm.xp) }
        .onChange(of: meets) { _, newValue in
            ballonDor.recordRequestIfNeeded(meets: newValue, xp: vm.xp)
        }
        .fullScreenCover(isPresented: Binding(
            get: { ballonDor.approved && !ballonDor.celebrationSeen },
            set: { if !$0 { ballonDor.markCelebrationSeen() } }
        )) {
            BallonDorAwardView(coachName: ballonDor.approvedBy) {}
        }
    }

    // MARK: - 1. Header

    private func header(_ vm: AcademyProgressionViewModel) -> some View {
        let rank = vm.currentRank
        return VStack(spacing: 0) {
            Monogram(size: 72, initials: rank.numeral, kit: PlayerProfileStore.shared.kitNumber)

            Text(rank.title)
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s16)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s4) {
                Text(vm.xp.formatted())
                    .font(DS.Typography.num(size: 36))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("XP")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            .padding(.top, DS.Spacing.s8)

            Eyebrow(text: "Academy Rank · \(rank.numeral)")
                .padding(.top, DS.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - 2. Next Rank Card

    private func nextRankCard(_ vm: AcademyProgressionViewModel) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Next Rank")

                if let next = vm.nextRank {
                    let nextLocked = subscription.isRankLocked(next)

                    HStack(spacing: DS.Spacing.s8) {
                        Text(next.title)
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        if nextLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                        }
                    }
                    .padding(.top, DS.Spacing.s4 + 2)

                    ProgressBar(value: vm.progressToNext)
                        .padding(.top, DS.Spacing.s12)

                    if nextLocked {
                        Text(vm.hasLockedEarnedRank
                             ? "XP unlocked — Elite required to claim this rank"
                             : "Reach the XP and go Elite to unlock this rank")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .padding(.top, DS.Spacing.s8)

                        Button {
                            subscription.presentPaywall()
                        } label: {
                            HStack(spacing: DS.Spacing.s8) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Unlock with Elite")
                                    .style(.foot)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.s12)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.top, DS.Spacing.s12)
                    } else {
                        Text("\((vm.xpToNext ?? 0).formatted()) XP to go")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .padding(.top, DS.Spacing.s8)
                    }
                } else {
                    Text("Highest rank achieved")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(.top, DS.Spacing.s4 + 2)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - 3. Rank Timeline

    private func timelineSection(_ vm: AcademyProgressionViewModel, bdState: BallonDorState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "The Pathway")

            VStack(spacing: 0) {
                ForEach(Array(AcademyRank.allCases.enumerated()), id: \.element) { index, rank in
                    let memberLocked = subscription.isRankLocked(rank)
                    let node = RankNode(
                        rank: rank,
                        state: state(for: rank, current: vm.currentRank, next: vm.nextRank),
                        isMemberLocked: memberLocked,
                        isLast: false
                    )
                    if memberLocked {
                        Button {
                            subscription.presentPaywall()
                        } label: { node }
                        .buttonStyle(PressableButtonStyle())
                    } else {
                        node
                    }
                }
                BallonDorNode(
                    state: bdState,
                    coachName: ballonDor.approvedBy,
                    requirementText: BallonDor.requirementSummary(totalCategories: totalCategories)
                )
            }
            .padding(.top, DS.Spacing.s16)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    private func state(for rank: AcademyRank, current: AcademyRank, next: AcademyRank?) -> RankNodeState {
        if subscription.isRankLocked(rank) { return .locked }
        if rank == current { return .current }
        if rank.rawValue < current.rawValue { return .achieved }
        if let next, rank == next { return .next }
        return .locked
    }

    // MARK: - 4. Skill Mastery

    private func skillMasterySection(_ vm: AcademyProgressionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Skill Mastery")

            VStack(spacing: DS.Spacing.s12 - 2) {
                ForEach(vm.disciplines) { discipline in
                    let pct = vm.disciplineMasteryPercent(for: discipline)
                    VStack(spacing: DS.Spacing.s4 + 2) {
                        HStack(spacing: DS.Spacing.s8) {
                            DisciplineMark(kind: discipline.mark, size: 16)
                            Text(discipline.name)
                                .style(.foot)
                                .fontWeight(.semibold)
                                .foregroundStyle(DS.Colors.Ink.primary)
                            Spacer()
                            Text("\(Int((pct * 100).rounded()))%")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                        }
                        ProgressBar(value: pct)
                    }
                }
            }
            .padding(.top, DS.Spacing.s12 + 2)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - 5. Development Milestones

    private func milestonesSection(_ vm: AcademyProgressionViewModel) -> some View {
        let rows: [(String, String)] = [
            ("Streak personal best", "\(vm.streakPB) days"),
            ("Certifications earned", "\(vm.certCount) of \(totalCategories)"),
            ("Drills logged", "\(vm.totalDrillsLogged)"),
            ("This week", "\(vm.weeklyConsistencyPercent)%")
        ]
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Development Milestones")

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    VStack(spacing: 0) {
                        HStack {
                            Text(row.0)
                                .style(.callout)
                                .foregroundStyle(DS.Colors.Ink.secondary)
                            Spacer()
                            Text(row.1)
                                .font(DS.Typography.num(size: 18))
                                .foregroundStyle(DS.Colors.Ink.primary)
                        }
                        .padding(.vertical, DS.Spacing.s12 + 2)

                        if index < rows.count - 1 {
                            Hairline()
                        }
                    }
                }
            }
            .padding(.top, DS.Spacing.s12 + 2)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }
}

// MARK: - Rank Node

enum RankNodeState {
    case achieved
    case current
    case next
    case locked
}

private struct RankNode: View {
    let rank: AcademyRank
    let state: RankNodeState
    var isMemberLocked: Bool = false
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.s16) {
            // Node + connecting line
            VStack(spacing: 0) {
                nodeCircle
                Rectangle()
                    .fill(DS.Colors.Line.hairline)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                HStack(spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Rank \(rank.numeral)")
                    if state == .current {
                        youAreHereChip
                    } else if isMemberLocked {
                        membersChip
                    }
                }
                Text(rank.title)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("\(rank.rawValue.formatted()) XP")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                if state == .achieved {
                    Text("Achieved")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                } else if isMemberLocked {
                    Text("Elite required")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
            }
            .padding(.bottom, DS.Spacing.s20)

            Spacer(minLength: 0)
        }
        .opacity(state == .locked ? 0.7 : 1)
    }

    @ViewBuilder
    private var nodeCircle: some View {
        switch state {
        case .achieved, .current:
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(rank.numeral)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(DS.Colors.Ground.primary)
                )
        case .next:
            Circle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(rank.numeral)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(DS.Colors.Ink.primary)
                )
        case .locked:
            Circle()
                .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                .frame(width: 44, height: 44)
                .overlay(
                    Group {
                        if isMemberLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ink.disabled)
                        } else {
                            Text(rank.numeral)
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(DS.Colors.Ink.disabled)
                        }
                    }
                )
        }
    }

    private var membersChip: some View {
        HStack(spacing: DS.Spacing.s4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 8, weight: .bold))
            Text("Members")
                .style(.microSm)
        }
        .foregroundStyle(DS.Colors.Ink.tertiary)
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.pill)
                .stroke(DS.Colors.Line.subtle, lineWidth: 1)
        )
    }

    private var youAreHereChip: some View {
        Text("You Are Here")
            .style(.micro)
            .foregroundStyle(DS.Colors.Ground.primary)
            .padding(.vertical, 4)
            .padding(.horizontal, DS.Spacing.s8 + 2)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }
}

/// The invite-only top tier of the timeline. Reflects the Ballon d'Or state:
/// locked (requirements shown), pending (coach review), or approved (unlocked).
private struct BallonDorNode: View {
    let state: BallonDorState
    let coachName: String?
    let requirementText: String

    // The award surfaces used to hardcode Color(red: 0.86, green: 0.71, blue: 0.36)
    // (≈#DBB55C), which meant picking Crimson or Royal left this one node stubbornly
    // gold. These now resolve through the live accent.
    private static var accent: Color { DS.Colors.Gold.base }
    /// Small accent TYPE must use textLight at full opacity (GoldAccent.swift rules).
    private static var accentText: Color { DS.Colors.Gold.textLight }
    /// Ink for text sitting ON a solid accent fill — `.black` is wrong for Royal.
    private static var accentInk: Color { DS.Colors.Gold.inkOnGold }
    private var isApproved: Bool { state == .approved }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.s16) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isApproved ? AnyShapeStyle(Self.accent) : AnyShapeStyle(Color.clear))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().stroke(isApproved ? Self.accent : DS.Colors.Line.subtle, lineWidth: isApproved ? 0 : 1)
                    )
                    .overlay(
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isApproved ? Self.accentInk : (state == .locked ? DS.Colors.Ink.disabled : Self.accent))
                    )
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                HStack(spacing: DS.Spacing.s8) {
                    Eyebrow(text: AppConfigStore.shared.awardTitle)
                    if isApproved { approvedChip } else if state == .pending || state == .eligible { reviewChip }
                }
                Text(AppConfigStore.shared.awardTitle)
                    .style(.title3)
                    // Titles stay white per the design system's contrast rules —
                    // this was rendering 17pt semibold in raw accent on black.
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(subtitle)
                    .style(.micro)
                    .foregroundStyle(isApproved ? DS.Colors.Ink.secondary : DS.Colors.Ink.quaternary)
            }

            Spacer(minLength: 0)
        }
        .opacity(state == .locked ? 0.7 : 1)
    }

    private var subtitle: String {
        switch state {
        case .locked:
            return "Coach MF Approved · Invite Only · \(requirementText)"
        case .eligible, .pending:
            return "Coach review · Your invitation is being considered"
        case .approved:
            if let coachName, !coachName.isEmpty { return "Invited by Coach \(coachName)" }
            return "Invitation granted"
        }
    }

    private var reviewChip: some View {
        HStack(spacing: DS.Spacing.s4) {
            Image(systemName: "hourglass")
                .font(.system(size: 8, weight: .bold))
            Text("Pending")
                .style(.microSm)
        }
        .foregroundStyle(Self.accentText)
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.pill)
                .stroke(DS.Colors.Gold.line, lineWidth: 1)
        )
    }

    private var approvedChip: some View {
        Text("Unlocked")
            .style(.microSm)
            .foregroundStyle(Self.accentInk)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(Self.accent)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }
}

#Preview {
    NavigationStack {
        AcademyProgressionView()
            .preferredColorScheme(.dark)
            .modelContainer(for: [
                Discipline.self, Category.self, MasteryLevel.self,
                Drill.self, DrillProgress.self, PlayerState.self
            ])
    }
}
