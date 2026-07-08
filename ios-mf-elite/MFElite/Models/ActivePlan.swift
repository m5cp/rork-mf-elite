//
//  ActivePlan.swift
//  MFElite
//
//  The single plan a player has committed to. At most one row exists.
//  Today's hero card renders from this; when nil, Today falls back to the
//  coach's Workout of the Day, then to the app default rotation.
//

import Foundation
import SwiftData

/// What kind of plan the player committed to.
enum ActivePlanKind: String, Codable {
    case routine        // a RoutineSpec from RoutineCatalog
    case customWorkout  // a player-built CustomWorkout
    case coachWorkout   // a coach-published CoachWorkout
}

@Model
final class ActivePlan {
    @Attribute(.unique) var id: UUID
    /// Raw value of ActivePlanKind.
    var kind: String
    /// RoutineSpec.id, CustomWorkout.id.uuidString, or CoachWorkout.id.uuidString.
    var referenceID: String
    /// Display title snapshot (survives source deletion).
    var title: String
    /// Ordered sessions; each session is an ordered list of drill IDs.
    /// Single-session sources produce one entry.
    var sessions: [[String]]
    /// Index of the next session to play (0-based). Clamp to sessions.count - 1.
    var currentSessionIndex: Int
    var startedAt: Date

    init(
        id: UUID = UUID(),
        kind: ActivePlanKind,
        referenceID: String,
        title: String,
        sessions: [[String]],
        currentSessionIndex: Int = 0,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind.rawValue
        self.referenceID = referenceID
        self.title = title
        self.sessions = sessions
        self.currentSessionIndex = currentSessionIndex
        self.startedAt = startedAt
    }

    var isFinished: Bool { currentSessionIndex >= sessions.count }
    var progressLabel: String {
        sessions.count > 1
            ? "Session \(min(currentSessionIndex + 1, sessions.count)) of \(sessions.count)"
            : ""
    }
}

extension ActivePlan {
    /// Commit a new plan: removes any existing rows so at most one plan exists,
    /// inserts the new one, and saves.
    static func commit(_ plan: ActivePlan, in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ActivePlan>())) ?? []
        for row in existing { context.delete(row) }
        context.insert(plan)
        try? context.save()
    }
}
