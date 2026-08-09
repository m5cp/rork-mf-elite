//
//  RankDetailView.swift
//  MFElite
//
//  The player's current rank with a full XP breakdown showing exactly how
//  every point was earned, plus XP split by discipline.
//

import SwiftUI
import SwiftData

/// Navigation route to the rank & XP detail screen.
struct RankDetailRoute: Hashable {}

struct RankDetailView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var players: [PlayerState]
    // The breakdown is reconciled against real records rather than mastery
    // state, so this screen reads the session log and the watch workouts.
    @Query private var sessions: [SessionLogEntry]
    @Query private var workouts: [WorkoutRecord]
    @Environment(SubscriptionService.self) private var subscription

    private var profile = PlayerProfileStore.shared

    private var viewModel: RankDetailViewModel {
        RankDetailViewModel(
            disciplines: disciplines,
            earnedXP: players.first?.xp ?? 0,
            purchasedXP: players.first?.purchasedXP ?? 0,
            sessions: sessions,
            workouts: workouts
        )
    }

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(vm)
                nextRankCard(vm)
                breakdownSection(vm)
                byDisciplineSection(vm)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 1. Header

    private func header(_ vm: RankDetailViewModel) -> some View {
        let rank = vm.currentRank
        return VStack(spacing: 0) {
            ArtworkBanner(name: MFArtwork.rank)
                .padding(.bottom, DS.Spacing.s20)

            Monogram(size: 80, initials: rank.numeral, kit: profile.kitNumber)

            Eyebrow(text: "Rank \(rank.numeral)")
                .padding(.top, DS.Spacing.s16)

            Text(rank.title)
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s4)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s4) {
                Text(vm.rankXP.formatted())
                    .font(DS.Typography.num(size: 40))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("XP")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            .padding(.top, DS.Spacing.s8)

            NavigationLink(value: MFStoreRoute()) {
                HStack(spacing: DS.Spacing.s4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Get more XP")
                        .style(.foot)
                }
                .foregroundStyle(DS.Colors.Ground.primary)
                .padding(.vertical, DS.Spacing.s8)
                .padding(.horizontal, DS.Spacing.s16)
                .background(Color.white, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, DS.Spacing.s12)

            Label("Earn +5 XP for each platform you share your Player Card or Rep The Badge card to — up to 4 platforms a day.", systemImage: "square.and.arrow.up")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Colors.Ink.secondary)
                .padding(DS.Spacing.s12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.Bg.raised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s16)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - 2. Next Rank

    private func nextRankCard(_ vm: RankDetailViewModel) -> some View {
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

    // MARK: - 3. XP breakdown

    private func breakdownSection(_ vm: RankDetailViewModel) -> some View {
        // Bound once. `breakdownRows` filters and reduces the whole session log
        // and workout table, and the total used to re-run all of it a second
        // time on every render.
        let rows = vm.breakdownRows
        let total = rows.reduce(0) { $0 + $1.total }
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "How You Earned Them")

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    VStack(spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.label)
                                    .style(.callout)
                                    .foregroundStyle(DS.Colors.Ink.secondary)
                                Text(row.detail)
                                    .style(.micro)
                                    .foregroundStyle(DS.Colors.Ink.quaternary)
                            }
                            Spacer(minLength: DS.Spacing.s12)
                            Text(row.total.formatted())
                                .font(DS.Typography.num(size: 18))
                                .foregroundStyle(DS.Colors.Ink.primary)
                        }
                        .padding(.vertical, DS.Spacing.s12 + 2)
                        Hairline()
                    }
                }

                // Total — thicker top border to set it apart.
                Rectangle()
                    .fill(DS.Colors.Line.strong)
                    .frame(height: 1.5)

                HStack {
                    Text("Total")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Spacer()
                    Text(total.formatted())
                        .font(DS.Typography.num(size: 20))
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .padding(.vertical, DS.Spacing.s12 + 2)
            }
            .padding(.top, DS.Spacing.s12 + 2)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - 4. XP by discipline

    private func byDisciplineSection(_ vm: RankDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "By Discipline")

            // Says out loud why these rows don't reach the headline: only
            // training sits under a discipline — workouts, store XP and the
            // remainder above don't belong to any of them.
            Text("Training XP only — workouts and store XP aren't tied to a discipline.")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .padding(.top, DS.Spacing.s8)

            VStack(spacing: 0) {
                ForEach(Array(vm.disciplines.enumerated()), id: \.element.id) { index, discipline in
                    VStack(spacing: 0) {
                        HStack(spacing: DS.Spacing.s12) {
                            DisciplineMark(kind: discipline.mark, size: 18)
                            Text(discipline.name)
                                .style(.callout)
                                .foregroundStyle(DS.Colors.Ink.primary)
                            Spacer(minLength: 0)
                            Text(vm.xp(for: discipline).formatted())
                                .font(DS.Typography.num(size: 16))
                                .foregroundStyle(DS.Colors.Ink.primary)
                        }
                        .padding(.vertical, DS.Spacing.s12)

                        if index < vm.disciplines.count - 1 {
                            Hairline()
                        }
                    }
                }
            }
            .padding(.top, DS.Spacing.s12)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }
}

#Preview {
    NavigationStack {
        RankDetailView()
            .preferredColorScheme(.dark)
            .modelContainer(for: [
                Discipline.self, Category.self, MasteryLevel.self,
                Drill.self, DrillProgress.self, PlayerState.self,
                SessionLogEntry.self, WorkoutRecord.self
            ])
    }
}
