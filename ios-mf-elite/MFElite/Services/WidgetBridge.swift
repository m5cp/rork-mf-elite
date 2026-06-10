//
//  WidgetBridge.swift
//  MFElite
//
//  Publishes a small snapshot of the player's status (streak, XP, rank, today's
//  goals) into the shared App Group so the Home/Lock Screen widgets can render
//  it, then asks WidgetKit to refresh. Called after any progress change and at
//  launch. The widget reads the same keys from the App Group defaults.
//

import Foundation
import SwiftData
import WidgetKit

@MainActor
enum WidgetBridge {
    /// Shared App Group identifier — must match both targets' entitlements.
    static let appGroup = "group.app.rork.pgx8pb996dmcvbhdfnx8x"

    /// Keys written into the shared defaults.
    enum Key {
        static let streak = "widget.streak"
        static let xp = "widget.xp"
        static let rankNumeral = "widget.rankNumeral"
        static let rankTitle = "widget.rankTitle"
        static let goalsDone = "widget.goalsDone"
        static let goalsTotal = "widget.goalsTotal"
        static let trainedToday = "widget.trainedToday"
    }

    /// Recompute the snapshot from the model store and publish it.
    static func refresh(context: ModelContext) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }

        let player = try? context.fetch(FetchDescriptor<PlayerState>()).first
        let xp = player?.xp ?? 0
        let streak = player?.streak ?? 0
        let trainedToday = Calendar.current.isDateInToday(player?.lastTrainedDate ?? .distantPast)

        let rank = AcademyRank.unlockedRank(for: xp, hasFullAccess: SubscriptionService.shared.hasFullAccess)

        // Today's training volume → a simple 3-drill daily goal mirrors the
        // Today screen's default daily target.
        let sessions = (try? context.fetch(FetchDescriptor<SessionLogEntry>())) ?? []
        let goalTotal = 3
        let doneToday = sessions.filter { Calendar.current.isDateInToday($0.completedAt) }.count
        let goalsDone = min(goalTotal, doneToday)

        defaults.set(streak, forKey: Key.streak)
        defaults.set(xp, forKey: Key.xp)
        defaults.set(rank.numeral, forKey: Key.rankNumeral)
        defaults.set(rank.title, forKey: Key.rankTitle)
        defaults.set(goalsDone, forKey: Key.goalsDone)
        defaults.set(goalTotal, forKey: Key.goalsTotal)
        defaults.set(trainedToday, forKey: Key.trainedToday)

        WidgetCenter.shared.reloadAllTimelines()
    }
}
