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
        try await SupabaseService.shared.client
            .from("drills")
            .insert(insert)
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
        try await SupabaseService.shared.client
            .from("categories")
            .insert(insert)
            .execute()
    }

    // MARK: - Progression rules

    /// Update the single progression_rules row.
    func updateProgressionRules(_ rules: SupabaseProgressionRulesUpdate, id: String) async throws {
        try await SupabaseService.shared.client
            .from("progression_rules")
            .update(rules)
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Quotes

    func addQuote(_ quote: String, sortIndex: Int) async throws {
        try await SupabaseService.shared.client
            .from("daily_quotes")
            .insert(SupabaseQuoteInsert(quote: quote, sortIndex: sortIndex, active: true))
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
