//
//  BadgesLockerView.swift
//  MFElite
//
//  A visual badge collection mapped 1:1 to academy ranks, plus the invite-only
//  "The Eleven" tier.
//

import SwiftUI
import SwiftData

/// Navigation route to the badges locker.
struct BadgesRoute: Hashable {}

struct BadgesLockerView: View {
    @Query private var players: [PlayerState]

    /// Earned + purchased XP — rank badges mirror the player's academy rank.
    private var rankXP: Int { players.first?.rankXP ?? 0 }

    private var currentRank: AcademyRank { AcademyRank.rank(for: rankXP) }
    private var nextRank: AcademyRank? { AcademyRank.nextRank(for: rankXP) }

    /// All rank badges (earned when xp clears the threshold) plus achievements.
    private var earnedCount: Int {
        AcademyRank.allCases.filter { rankXP >= $0.rawValue }.count + AchievementStore.earnedCount
    }

    /// Rank badges + The Eleven + achievement badges.
    private var totalCount: Int {
        AcademyRank.allCases.count + 1 + AchievementBadge.allCases.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ladder
                achievementSection
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Achievement")
            Text("Badges")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s8)
            Text("\(earnedCount) of \(totalCount) earned")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .padding(.top, DS.Spacing.s8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - Ladder

    private var ladder: some View {
        VStack(spacing: 0) {
            ForEach(Array(AcademyRank.allCases.enumerated()), id: \.element) { index, rank in
                BadgeRow(state: state(for: rank), rank: rank, xpToGo: xpToGo(for: rank))
                Hairline()
            }
            ElevenBadgeRow()
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - Achievements

    private var achievementSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Achievements")
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s32)
                .padding(.bottom, DS.Spacing.s8)

            ForEach(AchievementBadge.allCases) { badge in
                let earned = AchievementStore.isEarned(badge)
                AchievementRow(badge: badge, isEarned: earned)
                Hairline()
                    .padding(.horizontal, DS.Spacing.s20)
            }
        }
    }

    // MARK: - State logic

    private func state(for rank: AcademyRank) -> BadgeState {
        if rankXP >= rank.rawValue { return .earned }
        if let next = nextRank, rank == next { return .target }
        return .locked
    }

    private func xpToGo(for rank: AcademyRank) -> Int {
        max(0, rank.rawValue - rankXP)
    }
}

// MARK: - Badge state

enum BadgeState {
    case earned
    case target
    case locked
}

// MARK: - Badge Row

private struct BadgeRow: View {
    let state: BadgeState
    let rank: AcademyRank
    let xpToGo: Int

    var body: some View {
        HStack(spacing: DS.Spacing.s16) {
            badgeIcon
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text("\(rank.title) Badge")
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("\(rank.rawValue.formatted()) XP")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                statusLabel
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.s16 + 2)
        .opacity(state == .locked ? 0.5 : 1)
    }

    @ViewBuilder
    private var badgeIcon: some View {
        switch state {
        case .earned:
            Circle()
                .fill(BadgeAccent.fill)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(rank.numeral)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(BadgeAccent.ink)
                )
        case .target:
            Circle()
                .stroke(BadgeAccent.stroke, lineWidth: 1.5)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(rank.numeral)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(BadgeAccent.text)
                )
        case .locked:
            Circle()
                .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.disabled)
                )
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch state {
        case .earned:
            HStack(spacing: DS.Spacing.s4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text("Earned")
                    .style(.micro)
            }
            .foregroundStyle(BadgeAccent.text)
        case .target:
            Text("In Progress · \(xpToGo.formatted()) XP to go")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        case .locked:
            Text("Locked")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.disabled)
        }
    }
}

// MARK: - The Eleven Badge

private struct ElevenBadgeRow: View {
    var body: some View {
        HStack(spacing: DS.Spacing.s16) {
            Circle()
                .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.disabled)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(AppConfigStore.shared.awardTitle)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("Coach MF Approved")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                Text("Coach MF Approved · Invite Only")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.disabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.s16 + 2)
        .opacity(0.5)
    }
}

// MARK: - Achievement Row

private struct AchievementRow: View {
    let badge: AchievementBadge
    let isEarned: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.s16) {
            Circle()
                .fill(isEarned ? BadgeAccent.fill : Color.clear)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: badge.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isEarned ? BadgeAccent.ink : DS.Colors.Ink.disabled)
                )
                .overlay(
                    Circle().stroke(isEarned ? Color.clear : DS.Colors.Line.subtle, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(badge.title)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(badge.detail)
                    .style(.micro)
                    .foregroundStyle(isEarned ? DS.Colors.Ink.tertiary : DS.Colors.Ink.disabled)
                if isEarned {
                    HStack(spacing: DS.Spacing.s4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Earned")
                            .style(.micro)
                    }
                    .foregroundStyle(BadgeAccent.text)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.s12)
        .padding(.horizontal, DS.Spacing.s20)
        .opacity(isEarned ? 1 : 0.5)
    }
}

#Preview {
    NavigationStack {
        BadgesLockerView()
            .preferredColorScheme(.dark)
            .modelContainer(for: [
                Discipline.self, Category.self, MasteryLevel.self,
                Drill.self, DrillProgress.self, PlayerState.self
            ])
    }
}

/// Accent resolvers for the badge surfaces. A "Badges" screen with no accent on
/// it was the clearest instance of the owner's complaint — earned badges are
/// exactly what an accent is for. Honors the monochrome preference.
private enum BadgeAccent {
    static var fill: Color {
        SymbolStyle.current == .accent ? DS.Colors.Gold.base : Color.white
    }
    static var ink: Color {
        SymbolStyle.current == .accent ? DS.Colors.Gold.inkOnGold : DS.Colors.Ground.primary
    }
    static var text: Color {
        SymbolStyle.current == .accent ? DS.Colors.Gold.textLight : DS.Colors.Ink.primary
    }
    static var stroke: Color {
        SymbolStyle.current == .accent ? DS.Colors.Gold.base : Color.white
    }
}
