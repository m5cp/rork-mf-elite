//
//  LeaderboardTeaserSection.swift
//  MFElite
//
//  "This Week's Leaderboard" teaser card for the Progress tab. Shows the top 3
//  of the weekly XP board (friends scope when the player has Game Center
//  friends, otherwise global) plus the player's own rank. Results are cached in
//  a shared model so the tab doesn't hit Game Center on every appearance —
//  refreshed on pull-to-refresh or when the cache is older than 10 minutes.
//  Tapping the card opens the full leaderboard; signed-out players get a
//  "See where you rank" prompt that triggers Game Center sign-in. All loads
//  fail soft to empty states when Game Center is unavailable.
//

import SwiftUI

/// Cached weekly-leaderboard snapshot shared across Progress tab appearances.
@MainActor
@Observable
final class LeaderboardTeaserModel {
    static let shared = LeaderboardTeaserModel()

    /// Top rows (at most 3) of the weekly board.
    private(set) var rows: [LeaderboardRow] = []
    /// The local player's own row, for the "You — #12 · 340 XP" line.
    private(set) var localRow: LeaderboardRow?
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    private var lastLoadedAt: Date?
    private static let staleInterval: TimeInterval = 10 * 60

    private init() {}

    /// Load only when the cache is missing or older than 10 minutes.
    func loadIfStale() async {
        if hasLoaded,
           let last = lastLoadedAt,
           Date().timeIntervalSince(last) < Self.staleInterval {
            return
        }
        await refresh()
    }

    /// Force a reload (pull-to-refresh). Fails soft to the previous data.
    func refresh() async {
        guard GameCenterService.shared.isAuthenticated, !isLoading else { return }
        isLoading = true

        // Prefer the friends board when the player actually has friends on it;
        // otherwise fall back to the global top of the weekly board.
        let friends = await GameCenterService.shared.loadFriendsLeaderboard(scope: .week)
        let hasFriends = friends.rows.contains { !$0.isLocalPlayer }
        let data: LeaderboardData
        if hasFriends {
            data = friends
        } else {
            data = await GameCenterService.shared.loadGlobalLeaderboard(scope: .week, limit: 3)
        }

        rows = Array(data.rows.prefix(3))
        localRow = data.localRow ?? data.rows.first { $0.isLocalPlayer }
        isLoading = false
        hasLoaded = true
        lastLoadedAt = Date()
    }
}

/// The teaser card rendered on the Progress tab.
struct LeaderboardTeaserCard: View {
    @State private var model = LeaderboardTeaserModel.shared
    @State private var gameCenter = GameCenterService.shared

    var body: some View {
        Group {
            if gameCenter.isAuthenticated {
                authenticatedCard
            } else {
                signInCard
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
        .task(id: gameCenter.isAuthenticated) {
            guard gameCenter.isAuthenticated else { return }
            await model.loadIfStale()
        }
    }

    // MARK: - Authenticated

    private var authenticatedCard: some View {
        NavigationLink(value: FriendsLeaderboardRoute()) {
            Card {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    HStack(spacing: DS.Spacing.s8) {
                        Eyebrow(text: "This Week's Leaderboard")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }

                    if model.isLoading && !model.hasLoaded {
                        loadingRow
                    } else if model.rows.isEmpty {
                        Text("No XP posted yet this week. Complete a drill to claim the top spot.")
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                                teaserRow(row)
                                if index != model.rows.count - 1 {
                                    Hairline()
                                }
                            }
                        }
                    }

                    if let local = model.localRow,
                       !model.rows.contains(where: { $0.isLocalPlayer }) {
                        Hairline()
                        Text("You — #\(local.rank) · \(local.score.formatted()) XP")
                            .style(.foot)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func teaserRow(_ row: LeaderboardRow) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            Text("\(row.rank)")
                .font(DS.Typography.num(size: 14))
                .foregroundStyle(row.isLocalPlayer ? DS.Colors.Ink.primary : DS.Colors.Ink.tertiary)
                .frame(width: 22, alignment: .leading)

            Text(row.displayName)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineLimit(1)

            if row.isLocalPlayer {
                Text("YOU")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 5)
                    .background(Color.white)
                    .clipShape(Capsule())
            }

            Spacer(minLength: DS.Spacing.s8)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s4) {
                Text(row.score.formatted())
                    .font(DS.Typography.num(size: 15))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("XP")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
        .padding(.vertical, DS.Spacing.s8)
    }

    private var loadingRow: some View {
        HStack(spacing: DS.Spacing.s12) {
            ProgressView()
                .tint(DS.Colors.Ink.tertiary)
            Text("Loading rankings…")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .padding(.vertical, DS.Spacing.s8)
    }

    // MARK: - Signed out

    private var signInCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            gameCenter.authenticate()
        } label: {
            Card {
                HStack(spacing: DS.Spacing.s16) {
                    Image(systemName: "trophy")
                        .font(.system(size: 20, weight: .semibold))
                        .metallicSymbol(.gold)
                        .frame(width: 44, height: 44)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                        Eyebrow(text: "This Week's Leaderboard")
                        Text("See where you rank")
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("Sign in to Game Center to join the weekly XP race")
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
    }
}
