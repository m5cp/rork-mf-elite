//
//  CoachContentService.swift
//  CoachContentService writes curriculum content to Supabase. RLS restricts
//  these mutations to users present in the `coaches` table.
//

import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class CoachContentService {
    static let shared = CoachContentService()

    var isPublishing: Bool = false
    var lastError: String?

    private let publishKey = "curriculum_publish_stamp"

    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Drills

    /// Insert a new drill under a level.
    func addDrill(to levelID: String, drill: SupabaseDrillInsert) async throws {
        var insert = drill
        if insert.levelId != levelID {
            insert = SupabaseDrillInsert(
                levelId: levelID,
                title: drill.title,
                focus: drill.focus,
                how: drill.how,
                videoUrl: drill.videoUrl,
                durationSec: drill.durationSec,
                sets: drill.sets,
                coachingPoints: drill.coachingPoints,
                sortIndex: drill.sortIndex
            )
        }
        try await client
            .from("drills")
            .insert(insert)
            .execute()
    }

    /// Update an existing drill's editable fields.
    func updateDrill(id: String, drill: SupabaseDrillInsert) async throws {
        try await client
            .from("drills")
            .update(drill)
            .eq("id", value: id)
            .execute()
    }

    /// Add a category to a discipline.
    func addCategory(to disciplineID: String, category: SupabaseCategoryInsert) async throws {
        var insert = category
        if insert.disciplineId != disciplineID {
            insert = SupabaseCategoryInsert(
                disciplineId: disciplineID,
                letter: category.letter,
                name: category.name,
                focus: category.focus,
                certName: category.certName,
                sortIndex: category.sortIndex
            )
        }
        try await client
            .from("categories")
            .insert(insert)
            .execute()
    }

    // MARK: - Progression rules

    /// Update the single progression_rules row.
    func updateProgressionRules(_ rules: SupabaseProgressionRulesUpdate, id: String) async throws {
        try await client
            .from("progression_rules")
            .update(rules)
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Quotes

    func fetchQuotes() async throws -> [SupabaseQuote] {
        try await client
            .from("daily_quotes")
            .select()
            .order("sort_index", ascending: true)
            .execute()
            .value
    }

    func addQuote(_ quote: String, sortIndex: Int) async throws {
        try await client
            .from("daily_quotes")
            .insert(SupabaseQuoteInsert(quote: quote, sortIndex: sortIndex, active: true))
            .execute()
    }

    func updateQuote(id: String, quote: String) async throws {
        try await client
            .from("daily_quotes")
            .update(SupabaseQuoteUpdate(quote: quote))
            .eq("id", value: id)
            .execute()
    }

    func deleteQuote(id: String) async throws {
        try await client
            .from("daily_quotes")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Announcements

    func fetchAnnouncements() async throws -> [SupabaseAnnouncement] {
        try await client
            .from("announcements")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func addAnnouncement(title: String, body: String) async throws {
        try await client
            .from("announcements")
            .insert(SupabaseAnnouncementInsert(title: title, body: body.isEmpty ? nil : body, active: true))
            .execute()
    }

    func setAnnouncementActive(id: String, active: Bool) async throws {
        try await client
            .from("announcements")
            .update(SupabaseAnnouncementActiveUpdate(active: active))
            .eq("id", value: id)
            .execute()
    }

    func deleteAnnouncement(id: String) async throws {
        try await client
            .from("announcements")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Coach note (parent report)

    /// The calendar month identifier the current monthly note covers, e.g. "2026-06".
    static func currentMonthKey(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    func fetchCoachNote(month: String) async throws -> SupabaseCoachNote? {
        let rows: [SupabaseCoachNote] = try await client
            .from("coach_notes")
            .select()
            .eq("month", value: month)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func saveCoachNote(month: String, body: String) async throws {
        try await client
            .from("coach_notes")
            .upsert(SupabaseCoachNoteUpsert(month: month, body: body), onConflict: "month")
            .execute()
    }

    // MARK: - Coaches (head-coach team management)

    /// All coaches (active + inactive) for the management list.
    func fetchCoaches() async throws -> [CoachRow] {
        try await client
            .from("coaches")
            .select()
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// Invite a new coach by email. They gain access on first Sign in with Apple
    /// using that email. RLS restricts this to head coaches.
    func addCoach(email: String, displayName: String, role: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        try await client
            .from("coaches")
            .insert(CoachInsert(
                email: normalizedEmail,
                displayName: name.isEmpty ? nil : name,
                role: role
            ))
            .execute()
    }

    /// Activate / deactivate a coach (revokes access without deleting the row).
    func setCoachActive(id: String, active: Bool) async throws {
        try await client
            .from("coaches")
            .update(CoachActiveUpdate(isActive: active))
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Publish

    /// Bump a local publish stamp so player apps know to re-fetch. In production
    /// this also writes a server-side `updated_at` flag the clients poll.
    func publishChanges() async {
        isPublishing = true
        defer { isPublishing = false }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: publishKey)
    }
}
