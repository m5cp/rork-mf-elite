//
//  ResumeStore.swift
//  MFElite
//
//  Remembers an interrupted training session so the player can drop back in
//  exactly where they left off. A lightweight, UserDefaults-backed snapshot of
//  the queue: which drills, in what order, the source it came from, and the
//  drill the player was on. Cleared when the session finishes or is dismissed,
//  and expires on its own after ~30 hours so it never feels stale.
//

import Foundation
import Observation

/// A serialized snapshot of an unfinished training session.
nonisolated struct ResumeSession: Codable, Equatable {
    var drillIDs: [String]
    var source: String
    var sourceName: String?
    var index: Int
    var savedAt: Date

    var count: Int { drillIDs.count }
    /// 1-based position of the drill the player was on.
    var position: Int { min(index + 1, count) }
}

@MainActor
@Observable
final class ResumeStore {
    static let shared = ResumeStore()

    private let defaults = UserDefaults.standard
    private let key = "MF_RESUME_SESSION"
    /// How long a saved session stays resumable before it's considered stale.
    private let ttl: TimeInterval = 60 * 60 * 30

    /// The current resumable session, if one exists and hasn't expired.
    private(set) var session: ResumeSession?

    private init() {
        load()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ResumeSession.self, from: data) else {
            session = nil
            return
        }
        if Date().timeIntervalSince(decoded.savedAt) > ttl || decoded.drillIDs.isEmpty {
            clear()
            return
        }
        session = decoded
    }

    /// Persist an in-progress session. Only meaningful for multi-drill runs.
    func save(drillIDs: [String], source: String, sourceName: String?, index: Int) {
        guard drillIDs.count > 1, index >= 0 else { return }
        let snapshot = ResumeSession(
            drillIDs: drillIDs,
            source: source,
            sourceName: sourceName,
            index: min(index, drillIDs.count - 1),
            savedAt: Date()
        )
        session = snapshot
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
        }
    }

    /// Forget the saved session (finished or dismissed).
    func clear() {
        session = nil
        defaults.removeObject(forKey: key)
    }

    /// Re-validate against the TTL — call when surfacing the resume card.
    func refresh() {
        load()
    }
}
