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
