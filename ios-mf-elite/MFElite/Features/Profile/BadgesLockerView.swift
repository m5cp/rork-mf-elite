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

    private var xp: Int { players.first?.xp ?? 0 }

    private var currentRank: AcademyRank { AcademyRank.rank(for: xp) }
    private var nextRank: AcademyRank? { AcademyRank.nextRank(for: xp) }

    /// All rank badges (earned when xp clears the threshold).
    private var earnedCount: Int {
        AcademyRank.allCases.filter { xp >= $0.rawValue }.count
    }

    /// Rank badges + The Eleven.
    private var totalCount: Int { AcademyRank.allCases.count + 1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ladder
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

    // MARK: - State logic

    private func state(for rank: AcademyRank) -> BadgeState {
        if xp >= rank.rawValue { return .earned }
        if let next = nextRank, rank == next { return .target }
        return .locked
    }

    private func xpToGo(for rank: AcademyRank) -> Int {
        max(0, rank.rawValue - xp)
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
                .fill(Color.white)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(rank.numeral)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(DS.Colors.Ground.primary)
                )
                .overlay(
                    Circle().stroke(DS.Colors.Line.strong, lineWidth: 1)
                )
        case .target:
            Circle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(rank.numeral)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(DS.Colors.Ink.primary)
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
            .foregroundStyle(DS.Colors.Ink.primary)
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
                    Image(systemName: "star.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.disabled)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text("The Eleven")
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("Invite only")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                Text("Invite Only · Coach-Selected")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.disabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.s16 + 2)
        .opacity(0.5)
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
