//
//  ReportDraftCache.swift
//  MFElite
//
//  Local, on-device autosave for the coach's in-progress report edits. Keyed by
//  player + period, written to the Documents directory so unsaved work survives
//  an app quit or crash. Cleared once the report is persisted to Supabase.
//

import Foundation

/// A locally-cached, unsaved snapshot of a report the coach is editing.
struct ReportDraft: Codable, Equatable {
    let playerID: String
    let period: String
    var reportID: String?
    var sections: [ReportSection]
    var savedAt: Date
}

/// File-backed store for `ReportDraft`s. All access is main-actor to match the
/// builder view that uses it; the payloads are tiny so disk I/O is negligible.
@MainActor
enum ReportDraftCache {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("report_drafts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(playerID: String, period: String) -> URL {
        let raw = "\(playerID)_\(period)"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safe = String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return directory.appendingPathComponent("\(safe).json")
    }

    static func save(_ draft: ReportDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        try? data.write(to: fileURL(playerID: draft.playerID, period: draft.period), options: .atomic)
    }

    static func load(playerID: String, period: String) -> ReportDraft? {
        let url = fileURL(playerID: playerID, period: period)
        guard let data = try? Data(contentsOf: url),
              let draft = try? JSONDecoder().decode(ReportDraft.self, from: data) else { return nil }
        return draft
    }

    static func clear(playerID: String, period: String) {
        try? FileManager.default.removeItem(at: fileURL(playerID: playerID, period: period))
    }
}
