//
//  ProgressReport.swift
//  MFElite
//
//  The coach-editable progress report: an ordered list of sections the coach
//  can edit, reorder, remove, and extend. Persisted per player per period in
//  the progress_reports table (sections as JSON). Prefilled from live data.
//

import Foundation

/// One section of a progress report. `kind` drives rendering; `title`,
/// `body`, and `ratings` are coach-editable. Auto sections carry generated
/// content the coach can overwrite freely.
struct ReportSection: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: Kind
    var title: String
    var body: String = ""
    /// For .ratings sections: label → 1...4 (Emerging/Developing/Proficient/Advanced).
    var ratings: [RatingRow] = []
    var included: Bool = true

    enum Kind: String, Codable {
        case header, freeText, ratings, autoCombine, autoConsistency, autoMastery, signature
    }

    struct RatingRow: Identifiable, Codable, Equatable {
        var id: UUID = UUID()
        var label: String
        var score: Int // 1...4
    }
}

extension ReportSection {
    static let ratingScale = ["", "Emerging", "Developing", "Proficient", "Advanced"]

    /// The recommended default template, in order. Auto sections are filled by
    /// the builder from live data; free-text sections start with guidance the
    /// coach replaces.
    static func defaultTemplate(playerName: String, period: String) -> [ReportSection] {
        [
            ReportSection(kind: .header, title: "Player Progress Report",
                          body: "\(playerName) · \(period)"),
            ReportSection(kind: .freeText, title: "Coach Summary",
                          body: ""),
            ReportSection(kind: .autoCombine, title: "Baseline & Combine Scores"),
            ReportSection(kind: .autoConsistency, title: "Training Consistency"),
            ReportSection(kind: .autoMastery, title: "Skills Mastery"),
            ReportSection(kind: .freeText, title: "Training Focus This Period",
                          body: ""),
            ReportSection(kind: .ratings, title: "Evaluation",
                          ratings: [
                            .init(label: "Technical / Ball Mastery", score: 2),
                            .init(label: "Physical / Athleticism", score: 2),
                            .init(label: "Game IQ / Decision Making", score: 2),
                            .init(label: "Attitude & Effort", score: 3),
                            .init(label: "Coachability", score: 3)
                          ]),
            ReportSection(kind: .freeText, title: "Strengths", body: ""),
            ReportSection(kind: .freeText, title: "Areas to Develop", body: ""),
            ReportSection(kind: .freeText, title: "Goals for Next Period", body: ""),
            ReportSection(kind: .signature, title: "Coach Signature",
                          body: "MF Elite Training Academy")
        ]
    }
}

/// Persistence to the progress_reports table.
@MainActor
enum ProgressReportStore {

    static func load(playerUserID: String, period: String) async -> (id: String, sections: [ReportSection], status: String)? {
        guard let rows = await SupabaseClient.shared.get(
            table: "progress_reports",
            query: [
                URLQueryItem(name: "player_user_id", value: "eq.\(playerUserID)"),
                URLQueryItem(name: "period", value: "eq.\(period)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        ), let row = rows.first,
           let id = row["id"] as? String else { return nil }
        let status = row["status"] as? String ?? "draft"
        var sections: [ReportSection] = []
        if let sectionsValue = row["sections"],
           let data = try? JSONSerialization.data(withJSONObject: sectionsValue),
           let decoded = try? JSONDecoder().decode([ReportSection].self, from: data) {
            sections = decoded
        }
        return (id, sections, status)
    }

    @discardableResult
    static func save(id: String?, playerUserID: String, period: String,
                     sections: [ReportSection], status: String) async -> Bool {
        guard let coachID = SupabaseAuth.shared.userID else { return false }
        guard let data = try? JSONEncoder().encode(sections),
              let json = try? JSONSerialization.jsonObject(with: data) else { return false }
        var row: [String: Any] = [
            "player_user_id": playerUserID,
            "coach_user_id": coachID,
            "period": period,
            "status": status,
            "sections": json,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        if let id { row["id"] = id }
        return await SupabaseClient.shared.upsert(table: "progress_reports", values: row, onConflict: "id")
    }
}
