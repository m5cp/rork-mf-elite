//
//  CurriculumSyncService.swift
//  MFElite
//
//  Fetches the remote curriculum from Supabase and caches it into SwiftData so
//  the app works fully offline after the first successful sync.
//

import Foundation
import SwiftData
import Observation
import Supabase

@MainActor
@Observable
final class CurriculumSyncService {
    static let shared = CurriculumSyncService()

    var isSyncing: Bool = false
    var lastError: String?

    private let lastSyncKey = "curriculum_last_sync"
    /// Re-sync at most once per hour unless forced.
    private let syncInterval: TimeInterval = 60 * 60

    private init() {}

    var lastSyncDate: Date? {
        let t = UserDefaults.standard.double(forKey: lastSyncKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// True when there has never been a sync, or the last one is stale.
    func shouldSync() -> Bool {
        guard let last = lastSyncDate else { return true }
        return Date().timeIntervalSince(last) > syncInterval
    }

    // MARK: - Curriculum

    /// Fetch all curriculum tables and upsert them into SwiftData.
    func syncCurriculum(context: ModelContext, force: Bool = false) async {
        guard force || shouldSync() else { return }
        guard SupabaseService.shared.isConfigured, AuthService.shared.isAuthenticated else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let client = SupabaseService.shared.client
            async let disciplines: [SupabaseDiscipline] = client.from("disciplines").select().execute().value
            async let categories: [SupabaseCategory] = client.from("categories").select().execute().value
            async let levels: [SupabaseLevel] = client.from("levels").select().execute().value
            async let drills: [SupabaseDrill] = client.from("drills").select().execute().value

            let (remoteDisciplines, remoteCategories, remoteLevels, remoteDrills) =
                try await (disciplines, categories, levels, drills)

            // Nothing came back — keep the existing (seeded) data rather than wiping it.
            guard !remoteDisciplines.isEmpty else {
                markSynced()
                return
            }

            try upsert(
                disciplines: remoteDisciplines,
                categories: remoteCategories,
                levels: remoteLevels,
                drills: remoteDrills,
                context: context
            )
            markSynced()
        } catch {
            lastError = error.localizedDescription
            print("[CurriculumSync] failed: \(error)")
        }
    }

    private func upsert(
        disciplines: [SupabaseDiscipline],
        categories: [SupabaseCategory],
        levels: [SupabaseLevel],
        drills: [SupabaseDrill],
        context: ModelContext
    ) throws {
        // Index existing local models by id.
        let existingDisciplines = Dictionary(
            (try context.fetch(FetchDescriptor<Discipline>())).map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        let existingCategories = Dictionary(
            (try context.fetch(FetchDescriptor<Category>())).map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        let existingLevels = Dictionary(
            (try context.fetch(FetchDescriptor<MasteryLevel>())).map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        let existingDrills = Dictionary(
            (try context.fetch(FetchDescriptor<Drill>())).map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        // Upsert disciplines.
        var disciplineByID: [String: Discipline] = [:]
        for dto in disciplines {
            let model = existingDisciplines[dto.id] ?? {
                let new = Discipline(id: dto.id, number: dto.number, name: dto.name, mark: dto.mark,
                                     tagline: dto.tagline ?? "", blurb: dto.blurb ?? "",
                                     media: dto.media ?? "drill", sortIndex: dto.sortIndex)
                context.insert(new)
                return new
            }()
            model.number = dto.number
            model.name = dto.name
            model.mark = dto.mark
            model.tagline = dto.tagline ?? ""
            model.blurb = dto.blurb ?? ""
            model.media = dto.media ?? "drill"
            model.sortIndex = dto.sortIndex
            disciplineByID[dto.id] = model
        }

        // Upsert categories.
        var categoryByID: [String: Category] = [:]
        for dto in categories {
            let model = existingCategories[dto.id] ?? {
                let new = Category(id: dto.id, letter: dto.letter, name: dto.name,
                                   focus: dto.focus ?? "", certName: dto.certName ?? "",
                                   sortIndex: dto.sortIndex)
                context.insert(new)
                return new
            }()
            model.letter = dto.letter
            model.name = dto.name
            model.focus = dto.focus ?? ""
            model.certName = dto.certName ?? ""
            model.sortIndex = dto.sortIndex
            if let parent = disciplineByID[dto.disciplineId], !parent.categories.contains(where: { $0.id == model.id }) {
                parent.categories.append(model)
            }
            categoryByID[dto.id] = model
        }

        // Upsert levels.
        var levelByID: [String: MasteryLevel] = [:]
        for dto in levels {
            let model = existingLevels[dto.id] ?? {
                let new = MasteryLevel(id: dto.id, number: dto.number, name: dto.name,
                                       theme: dto.theme ?? "", sortIndex: dto.sortIndex)
                context.insert(new)
                return new
            }()
            model.number = dto.number
            model.name = dto.name
            model.theme = dto.theme ?? ""
            model.sortIndex = dto.sortIndex
            if let parent = categoryByID[dto.categoryId], !parent.levels.contains(where: { $0.id == model.id }) {
                parent.levels.append(model)
            }
            levelByID[dto.id] = model
        }

        // Upsert drills.
        for dto in drills {
            let model = existingDrills[dto.id] ?? {
                let new = Drill(id: dto.id, title: dto.title, focus: dto.focus ?? "", how: dto.how ?? "",
                                videoURL: dto.videoUrl, durationSec: dto.durationSec, sets: dto.sets,
                                coachingPoints: dto.coachingPoints, sortIndex: dto.sortIndex)
                context.insert(new)
                return new
            }()
            model.title = dto.title
            model.focus = dto.focus ?? ""
            model.how = dto.how ?? ""
            model.videoURL = dto.videoUrl
            model.durationSec = dto.durationSec
            model.sets = dto.sets
            model.coachingPoints = dto.coachingPoints
            model.sortIndex = dto.sortIndex
            if let parent = levelByID[dto.levelId], !parent.drills.contains(where: { $0.id == model.id }) {
                parent.drills.append(model)
            }
        }

        // Delete local rows that are no longer present remotely.
        let remoteDrillIDs = Set(drills.map(\.id))
        for (id, model) in existingDrills where !remoteDrillIDs.contains(id) {
            context.delete(model)
        }
        let remoteLevelIDs = Set(levels.map(\.id))
        for (id, model) in existingLevels where !remoteLevelIDs.contains(id) {
            context.delete(model)
        }
        let remoteCategoryIDs = Set(categories.map(\.id))
        for (id, model) in existingCategories where !remoteCategoryIDs.contains(id) {
            context.delete(model)
        }
        let remoteDisciplineIDs = Set(disciplines.map(\.id))
        for (id, model) in existingDisciplines where !remoteDisciplineIDs.contains(id) {
            context.delete(model)
        }

        try context.save()
    }

    // MARK: - Progression rules / quotes

    /// Fetch the single progression_rules row and cache it into the local
    /// `ProgressionRules` store so XP rewards and free/paid gating follow the
    /// coach's published values. Returns the row (or nil if unavailable).
    @discardableResult
    func syncProgressionRules() async -> SupabaseProgressionRules? {
        guard SupabaseService.shared.isConfigured, AuthService.shared.isAuthenticated else { return nil }
        do {
            let rows: [SupabaseProgressionRules] = try await SupabaseService.shared.client
                .from("progression_rules")
                .select()
                .limit(1)
                .execute()
                .value
            if let rules = rows.first {
                ProgressionRules.apply(
                    xpPerDrill: rules.xpPerDrill,
                    xpLevelBonus: rules.xpLevelBonus,
                    xpCategoryCert: rules.xpCategoryCert,
                    xpDisciplineDiploma: rules.xpDisciplineDiploma,
                    freeLevels: rules.freeLevels,
                    masteryPasses: rules.masteryPasses
                )
            }
            return rows.first
        } catch {
            print("[CurriculumSync] rules failed: \(error)")
            return nil
        }
    }

    /// Fetch active announcements (newest first) for the player Today screen.
    func syncAnnouncements() async -> [SupabaseAnnouncement] {
        guard SupabaseService.shared.isConfigured, AuthService.shared.isAuthenticated else { return [] }
        do {
            return try await SupabaseService.shared.client
                .from("announcements")
                .select()
                .eq("active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            print("[CurriculumSync] announcements failed: \(error)")
            return []
        }
    }

    /// Fetch active daily quotes ordered by sort index.
    func syncQuotes() async -> [String] {
        guard SupabaseService.shared.isConfigured, AuthService.shared.isAuthenticated else { return [] }
        do {
            let rows: [SupabaseQuote] = try await SupabaseService.shared.client
                .from("daily_quotes")
                .select()
                .eq("active", value: true)
                .order("sort_index", ascending: true)
                .execute()
                .value
            return rows.map(\.quote)
        } catch {
            print("[CurriculumSync] quotes failed: \(error)")
            return []
        }
    }

    private func markSynced() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSyncKey)
    }
}
