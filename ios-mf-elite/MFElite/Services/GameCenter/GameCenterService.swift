//
//  GameCenterService.swift
//  MFElite
//
//  Game Center integration: authentication, XP leaderboard submission, and
//  achievement reporting. All Game Center IDs are defined here. The service is
//  fully wired in code; the leaderboards and achievements light up as soon as
//  they are created in App Store Connect. Every call no-ops safely when the
//  player is signed out or Game Center is unavailable, so the app never breaks.
//

import Foundation
import GameKit
import Observation
import UIKit

/// Game Center leaderboard identifiers. These must match the IDs configured in
/// App Store Connect.
enum GameCenterLeaderboard {
    /// All-time cumulative XP.
    static let allTimeXP = "mf.elite.leaderboard.xp.alltime"
    /// Rolling weekly XP (a recurring weekly board in App Store Connect).
    static let weeklyXP = "mf.elite.leaderboard.xp.weekly"

    static let all: [String] = [allTimeXP, weeklyXP]
}

/// Which XP board the in-app friends leaderboard is showing.
enum LeaderboardScope: String, CaseIterable, Identifiable {
    case week, allTime
    var id: String { rawValue }

    var label: String {
        switch self {
        case .week:    return "This Week"
        case .allTime: return "All Time"
        }
    }

    var leaderboardID: String {
        switch self {
        case .week:    return GameCenterLeaderboard.weeklyXP
        case .allTime: return GameCenterLeaderboard.allTimeXP
        }
    }
}

/// One row in the in-app friends leaderboard, flattened from a `GKLeaderboard.Entry`.
struct LeaderboardRow: Identifiable {
    let id: String
    let rank: Int
    let displayName: String
    let score: Int
    let isLocalPlayer: Bool
}

/// Resolved friends-leaderboard data: the ranked rows plus the local player's
/// own row (which may sit outside the visible range, so it can be pinned).
struct LeaderboardData {
    var rows: [LeaderboardRow]
    var localRow: LeaderboardRow?
}

@MainActor
@Observable
final class GameCenterService {
    static let shared = GameCenterService()

    /// True once the local player has successfully authenticated.
    private(set) var isAuthenticated = false

    /// The signed-in player's display name, when available.
    private(set) var localPlayerName: String?

    private init() {}

    // MARK: - Authentication

    /// Authenticate the local player. Call once at app launch. Presents Apple's
    /// sign-in sheet if needed; otherwise resolves silently.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    Self.present(viewController)
                } else if GKLocalPlayer.local.isAuthenticated {
                    self.isAuthenticated = true
                    self.localPlayerName = GKLocalPlayer.local.displayName
                } else {
                    self.isAuthenticated = false
                    if let error {
                        print("Game Center auth unavailable: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Leaderboards

    /// Submit the player's total XP to both the all-time and weekly boards.
    /// Safe to call after any XP-earning event.
    func submitXP(_ totalXP: Int) {
        guard isAuthenticated, totalXP > 0 else { return }
        Task {
            do {
                try await GKLeaderboard.submitScore(
                    totalXP,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: GameCenterLeaderboard.all
                )
            } catch {
                print("Game Center score submit failed: \(error.localizedDescription)")
            }
        }
    }

    /// Load the friends-only XP leaderboard for the given scope. Returns the
    /// ranked rows (friends + the local player) and the local player's own row
    /// so it can be pinned even when it falls outside the visible range.
    /// Returns empty data when signed out or on any failure — never throws.
    func loadFriendsLeaderboard(scope: LeaderboardScope) async -> LeaderboardData {
        guard isAuthenticated else { return LeaderboardData(rows: [], localRow: nil) }
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [scope.leaderboardID])
            guard let board = boards.first else { return LeaderboardData(rows: [], localRow: nil) }
            // Recurring (weekly) boards must use .allTime for the time scope.
            let (localEntry, entries, _) = try await board.loadEntries(
                for: .friendsOnly,
                timeScope: .allTime,
                range: NSRange(location: 1, length: 100)
            )
            let localID = GKLocalPlayer.local.gamePlayerID
            let rows = (entries ?? []).map { entry in
                Self.row(from: entry, localID: localID)
            }
            let localRow = localEntry.map { Self.row(from: $0, localID: localID) }
            return LeaderboardData(rows: rows, localRow: localRow)
        } catch {
            print("Game Center leaderboard load failed: \(error.localizedDescription)")
            return LeaderboardData(rows: [], localRow: nil)
        }
    }

    /// Loads the top `limit` global entries plus the local player's own entry
    /// (which may sit outside the top range, so it can be pinned). Returns empty
    /// data when signed out or on any failure — never throws.
    func loadGlobalLeaderboard(scope: LeaderboardScope, limit: Int = 50) async -> LeaderboardData {
        guard isAuthenticated else { return LeaderboardData(rows: [], localRow: nil) }
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [scope.leaderboardID])
            guard let board = boards.first else { return LeaderboardData(rows: [], localRow: nil) }
            // Recurring (weekly) boards must use .allTime for the time scope —
            // it resolves within the current occurrence.
            let (localEntry, entries, _) = try await board.loadEntries(
                for: .global,
                timeScope: .allTime,
                range: NSRange(location: 1, length: limit)
            )
            let localID = GKLocalPlayer.local.gamePlayerID
            let rows = (entries ?? []).map { entry in
                Self.row(from: entry, localID: localID)
            }
            let localRow = localEntry.map { Self.row(from: $0, localID: localID) }
            return LeaderboardData(rows: rows, localRow: localRow)
        } catch {
            print("Game Center global leaderboard load failed: \(error.localizedDescription)")
            return LeaderboardData(rows: [], localRow: nil)
        }
    }

    private static func row(from entry: GKLeaderboard.Entry, localID: String) -> LeaderboardRow {
        LeaderboardRow(
            id: entry.player.gamePlayerID,
            rank: entry.rank,
            displayName: entry.player.displayName,
            score: entry.score,
            isLocalPlayer: entry.player.gamePlayerID == localID
        )
    }

    // MARK: - Achievements

    /// Report a one-shot achievement as fully complete (100%).
    func reportAchievement(_ id: String) {
        report([(id, 100.0)])
    }

    /// Report incremental progress (0–100) toward an achievement.
    func reportProgress(_ id: String, percent: Double) {
        report([(id, min(max(percent, 0), 100))])
    }

    /// Report a batch of achievement progress values at once.
    func report(_ items: [(id: String, percent: Double)]) {
        guard isAuthenticated, !items.isEmpty else { return }
        let achievements = items.map { item -> GKAchievement in
            let a = GKAchievement(identifier: item.id)
            a.percentComplete = item.percent
            a.showsCompletionBanner = true
            return a
        }
        Task {
            do {
                try await GKAchievement.report(achievements)
            } catch {
                print("Game Center achievement report failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Native dashboard

    /// Present the native Game Center dashboard at the given state.
    func showDashboard(state: GKGameCenterViewControllerState = .leaderboards) {
        guard isAuthenticated else { return }
        let vc = GKGameCenterViewController(state: state)
        vc.gameCenterDelegate = DashboardDelegate.shared
        Self.present(vc)
    }

    /// Open the native dashboard focused on a specific leaderboard.
    func showLeaderboard(_ leaderboardID: String) {
        guard isAuthenticated else { return }
        let vc = GKGameCenterViewController(
            leaderboardID: leaderboardID,
            playerScope: .global,
            timeScope: .allTime
        )
        vc.gameCenterDelegate = DashboardDelegate.shared
        Self.present(vc)
    }

    // MARK: - Helpers

    private static func present(_ viewController: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.keyWindow?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(viewController, animated: true)
    }
}

/// Shared delegate that dismisses the Game Center dashboard when finished.
private final class DashboardDelegate: NSObject, GKGameCenterControllerDelegate {
    static let shared = DashboardDelegate()

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
