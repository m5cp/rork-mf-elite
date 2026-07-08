//
//  FriendsLeaderboardView.swift
//  MFElite
//
//  In-app XP leaderboard. Pulls friends-only or global scores from Game Center
//  for the weekly or all-time board, highlights the player's own row, and pins
//  their standing so it's always visible. Falls back to friendly sign-in /
//  no-friends states, with a shortcut into the native Game Center dashboard
//  for managing friends.
//

import SwiftUI
import GameKit

/// Navigation route to the in-app leaderboard.
struct FriendsLeaderboardRoute: Hashable {}

/// Who the leaderboard compares the player against.
enum LeaderboardPlayerScope: String, CaseIterable, Identifiable {
    case friends, everyone
    var id: String { rawValue }

    var label: String {
        switch self {
        case .friends:  return "Friends"
        case .everyone: return "Everyone"
        }
    }
}

struct FriendsLeaderboardView: View {
    @State private var gameCenter = GameCenterService.shared
    @State private var scope: LeaderboardScope = .week
    @State private var playerScope: LeaderboardPlayerScope = .friends
    @State private var data = LeaderboardData(rows: [], localRow: nil)
    @State private var isLoading = false
    @State private var hasLoadedOnce = false

    /// Reload key covering both the board (week/all-time) and player scope.
    private var loadKey: String { "\(playerScope.rawValue)-\(scope.rawValue)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if gameCenter.isAuthenticated {
                    playerScopePicker
                    scopePicker
                    content
                } else {
                    signedOutState
                }
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: loadKey) {
            guard gameCenter.isAuthenticated else { return }
            await load()
        }
        .refreshable {
            guard gameCenter.isAuthenticated else { return }
            await load()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Game Center")
            Text("Leaderboard")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(playerScope == .friends
                 ? "See how your XP stacks up against the friends you train with."
                 : "See how your XP stacks up against every player in the app.")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Scope pickers

    private var playerScopePicker: some View {
        HStack(spacing: DS.Spacing.s8) {
            ForEach(LeaderboardPlayerScope.allCases) { option in
                segmentButton(
                    label: option.label,
                    isSelected: playerScope == option
                ) {
                    guard playerScope != option else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(DS.Motion.standardSpring) { playerScope = option }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    private var scopePicker: some View {
        HStack(spacing: DS.Spacing.s8) {
            ForEach(LeaderboardScope.allCases) { option in
                segmentButton(
                    label: option.label,
                    isSelected: scope == option
                ) {
                    guard scope != option else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(DS.Motion.standardSpring) { scope = option }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s12)
    }

    private func segmentButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .style(.foot)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? DS.Colors.Ground.primary : DS.Colors.Ink.tertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(isSelected ? Color.white : DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.pill)
                        .stroke(isSelected ? Color.clear : DS.Colors.Line.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        if isLoading && !hasLoadedOnce {
            loadingState
        } else if data.rows.isEmpty {
            emptyState
        } else {
            leaderboardList
        }
    }

    private var leaderboardList: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.rows.enumerated()), id: \.element.id) { index, row in
                rowView(row)
                if index != data.rows.count - 1 {
                    Hairline()
                }
            }

            // Pin the player's own standing when it falls outside the loaded rows.
            if let localRow = data.localRow,
               !data.rows.contains(where: { $0.isLocalPlayer }) {
                Hairline()
                Text("Your standing")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, DS.Spacing.s16)
                rowView(localRow)
            }

            manageFriendsButton
                .padding(.top, DS.Spacing.s24)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s12)
    }

    private func rowView(_ row: LeaderboardRow) -> some View {
        HStack(spacing: DS.Spacing.s16) {
            Text("\(row.rank)")
                .font(DS.Typography.num(size: 16))
                .foregroundStyle(row.isLocalPlayer ? DS.Colors.Ink.primary : DS.Colors.Ink.tertiary)
                .frame(width: 32, alignment: .leading)

            Text(row.displayName)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineLimit(1)

            if row.isLocalPlayer {
                Text("YOU")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(Color.white)
                    .clipShape(Capsule())
            }

            Spacer(minLength: DS.Spacing.s8)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s4) {
                Text(row.score.formatted())
                    .font(DS.Typography.num(size: 18))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("XP")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
        .padding(.vertical, DS.Spacing.s16)
        .padding(.horizontal, row.isLocalPlayer ? DS.Spacing.s16 : 0)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(row.isLocalPlayer ? DS.Colors.Bg.raised : Color.clear)
        )
    }

    private var loadingState: some View {
        VStack(spacing: DS.Spacing.s16) {
            ProgressView()
                .tint(DS.Colors.Ink.tertiary)
            Text(playerScope == .friends ? "Loading friends…" : "Loading rankings…")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.s64)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Card {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: playerScope == .friends ? "No friends yet" : "No scores yet")
                    Text(playerScope == .friends
                         ? "Add friends in Game Center to start a leaderboard. Train together, push each other, and watch the XP race heat up."
                         : "No one has posted XP on this board yet. Complete a drill and be the first on the leaderboard.")
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            manageFriendsButton
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    private var signedOutState: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            Card {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Sign in to Game Center")
                    Text("Sign in to Game Center to see how your XP compares with friends. Open Settings › Game Center on your device, then come back.")
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PrimaryButton(label: "Retry sign in") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                gameCenter.authenticate()
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    private var manageFriendsButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            gameCenter.showLeaderboard(scope.leaderboardID)
        } label: {
            HStack(spacing: DS.Spacing.s8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Open in Game Center")
                    .style(.foot)
                    .fontWeight(.semibold)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(DS.Colors.Ink.tertiary)
            .padding(.vertical, DS.Spacing.s16)
            .padding(.horizontal, DS.Spacing.s16)
            .frame(maxWidth: .infinity)
            .background(DS.Colors.Bg.raised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.Line.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        let result: LeaderboardData
        switch playerScope {
        case .friends:
            result = await gameCenter.loadFriendsLeaderboard(scope: scope)
        case .everyone:
            result = await gameCenter.loadGlobalLeaderboard(scope: scope)
        }
        data = result
        isLoading = false
        hasLoadedOnce = true
    }
}

#Preview {
    NavigationStack {
        FriendsLeaderboardView()
    }
    .preferredColorScheme(.dark)
}
