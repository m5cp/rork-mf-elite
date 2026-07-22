//
//  CurriculumOverlay.swift
//  MFElite
//
//  Applies coach-published curriculum edits (the remote `curriculum_edits` table)
//  as a purely additive overlay onto the local SwiftData curriculum. Edits change
//  drill CONTENT only — they never touch a player's progress, history, streaks,
//  favorites, routines, or custom workouts (all keyed independently by drill id).
//
//  Flow: on launch we re-apply the durable local cache (so coach content survives
//  re-seeds and works offline), then — at most once per 24h — fetch the active
//  remote edits, reconcile the cache, and re-apply. Any fetch/parse failure keeps
//  the current content silently and retries next day.
//

import Foundation
import SwiftData

@MainActor
enum CurriculumOverlay {
    private static let lastFetchKey = "MF_CURRICULUM_EDITS_LAST_FETCH"
    private static let fetchInterval: TimeInterval = 24 * 60 * 60

    /// Re-apply cached edits immediately, then refresh from the server when the
    /// 24h window has elapsed. Fully async; never blocks the UI.
    static func applyAndMaybeRefresh(context: ModelContext) async {
        // 1) Re-apply whatever we already have (works offline / after re-seed).
        applyCache(context: context)

        // 2) Once per 24h, pull the latest active edits.
        let last = UserDefaults.standard.double(forKey: lastFetchKey)
        let due = last <= 0 || Date().timeIntervalSince1970 - last >= fetchInterval
        guard due else { return }

        await refresh(context: context)
    }

    /// Force a fetch + reconcile + re-apply (ignores the 24h gate). Used by the
    /// coach editor after publishing so changes preview right away.
    static func refresh(context: ModelContext) async {
        let rows = await SupabaseClient.shared.get(
            table: "curriculum_edits",
            query: [
                URLQueryItem(name: "active", value: "eq.true"),
                URLQueryItem(name: "select", value: "drill_id,kind,payload,updated_by,category_id,level_number")
            ]
        )
        // nil = request failed → keep the current cache + content, retry next day.
        guard let rows else { return }

        reconcileCache(with: rows, context: context)
        applyCache(context: context)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)
    }

    // MARK: - Cache reconciliation

    /// Merge the active remote rows into the local cache. New rows are inserted
    /// (stamping firstSeenAt now), changed rows updated (preserving firstSeenAt),
    /// and rows no longer active are removed — undoing their content effect.
    private static func reconcileCache(with rows: [[String: Any]], context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<CurriculumEditCache>())) ?? []
        var byID = Dictionary(existing.map { ($0.drillID, $0) }, uniquingKeysWith: { a, _ in a })

        var activeIDs = Set<String>()
        for row in rows {
            guard let drillID = row["drill_id"] as? String,
                  let kind = row["kind"] as? String else { continue }
            activeIDs.insert(drillID)

            let payloadDict = (row["payload"] as? [String: Any]) ?? [:]
            let payloadData = (try? JSONSerialization.data(withJSONObject: payloadDict)) ?? Data("{}".utf8)
            let updatedBy = (row["updated_by"] as? String) ?? "Coach"
            let categoryID = row["category_id"] as? String
            let levelNumber = (row["level_number"] as? Int) ?? 0

            if let cached = byID[drillID] {
                cached.kind = kind
                cached.payloadJSON = payloadData
                cached.updatedBy = updatedBy
                cached.categoryID = categoryID
                cached.levelNumber = levelNumber
            } else {
                let cached = CurriculumEditCache(
                    drillID: drillID,
                    kind: kind,
                    payloadJSON: payloadData,
                    updatedBy: updatedBy,
                    categoryID: categoryID,
                    levelNumber: levelNumber
                )
                context.insert(cached)
                byID[drillID] = cached
            }
        }

        // Anything cached but no longer active → revert its effect, then drop it.
        for cached in existing where !activeIDs.contains(cached.drillID) {
            undo(cached, context: context)
            context.delete(cached)
        }
        try? context.save()
    }

    // MARK: - Applying edits

    /// Apply every cached edit onto the local curriculum graph.
    private static func applyCache(context: ModelContext) {
        let cache = (try? context.fetch(FetchDescriptor<CurriculumEditCache>())) ?? []
        if !cache.isEmpty {
            let drills = (try? context.fetch(FetchDescriptor<Drill>())) ?? []
            var drillByID = Dictionary(drills.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

            for cached in cache {
                switch cached.kind {
                case "edit":
                    if let drill = drillByID[cached.drillID] {
                        merge(cached.payload, onto: drill)
                        drill.coachEditedBy = cached.updatedBy
                    }
                case "hide":
                    drillByID[cached.drillID]?.isCoachHidden = true
                case "new":
                    if let drill = applyNew(cached, existing: drillByID[cached.drillID], context: context) {
                        drillByID[cached.drillID] = drill
                    }
                default:
                    break
                }
            }
        }
        applyNameOverrides(context: context)
        try? context.save()
    }

    /// Apply head-coach content renames (app_config `content_overrides`) onto
    /// the local curriculum models, so every screen that reads these models
    /// picks up the new name automatically. Additive-only, like every other
    /// overlay here: player progress, history, and identity keys never change.
    private static func applyNameOverrides(context: ModelContext) {
        let store = AppConfigStore.shared
        guard !store.overrides.isEmpty else { return }
        let disciplines = (try? context.fetch(FetchDescriptor<Discipline>())) ?? []
        for discipline in disciplines {
            if let name = store.overrideName(kind: "discipline", id: discipline.id) {
                discipline.name = name
            }
            for category in discipline.categories {
                if let name = store.overrideName(kind: "category", id: category.id) {
                    category.name = name
                }
                if let certName = store.overrideName(kind: "certification", id: category.id) {
                    category.certName = certName
                }
                for level in category.levels {
                    if let name = store.overrideName(kind: "level", id: level.id) {
                        level.name = name
                    }
                    for drill in level.drills {
                        if let name = store.overrideName(kind: "drill", id: drill.id) {
                            drill.title = name
                        }
                    }
                }
            }
        }
        let combineTests = (try? context.fetch(FetchDescriptor<CombineTest>())) ?? []
        for test in combineTests {
            if let name = store.overrideName(kind: "combine_test", id: test.id) {
                test.name = name
            }
        }
    }

    /// Insert (or refresh) a coach-authored "new" drill into its category/level.
    /// Skips silently when the target category/level doesn't exist in this build.
    @discardableResult
    private static func applyNew(_ cached: CurriculumEditCache, existing: Drill?, context: ModelContext) -> Drill? {
        // Already inserted previously — just refresh its content.
        if let drill = existing {
            merge(cached.payload, onto: drill)
            drill.coachEditedBy = cached.updatedBy
            if drill.coachNewSince == nil { drill.coachNewSince = cached.firstSeenAt }
            return drill
        }

        guard let categoryID = cached.categoryID else { return nil }
        let disciplines = (try? context.fetch(FetchDescriptor<Discipline>())) ?? []
        var targetLevel: MasteryLevel?
        for discipline in disciplines {
            guard let category = discipline.categories.first(where: { $0.id == categoryID }) else { continue }
            let levels = category.levels.sorted(by: { $0.sortIndex < $1.sortIndex })
            targetLevel = levels.first(where: { $0.number == cached.levelNumber }) ?? levels.first
            break
        }
        guard let level = targetLevel else { return nil }   // category absent → skip

        let payload = cached.payload
        let nextSort = (level.drills.map(\.sortIndex).max() ?? 0) + 1

        let title = (payload["title"] as? String) ?? "Coach Drill"
        let focus = (payload["focus"] as? String) ?? ""
        let how = (payload["how"] as? String) ?? ""
        let durationSec = (payload["durationSec"] as? Int) ?? 300
        let sets = (payload["sets"] as? Int) ?? 1
        let coachingPoints = (payload["coachingPoints"] as? [String]) ?? []
        let instructions = (payload["instructions"] as? [String]) ?? []
        let videoURL = payload["videoURL"] as? String
        let imageURL = payload["imageURL"] as? String
        let equipment = (payload["equipment"] as? [String]) ?? []
        let space = payload["space"] as? String

        let drill = Drill(
            id: cached.drillID,
            title: title,
            focus: focus,
            how: how,
            videoURL: videoURL,
            imageURL: imageURL,
            durationSec: durationSec,
            sets: sets,
            coachingPoints: coachingPoints,
            instructions: instructions,
            sortIndex: nextSort,
            equipment: equipment,
            space: space
        )
        drill.coachEditedBy = cached.updatedBy
        drill.coachNewSince = cached.firstSeenAt
        level.drills.append(drill)
        return drill
    }

    /// Merge changed content fields onto a drill. Only keys present are touched.
    private static func merge(_ payload: [String: Any], onto drill: Drill) {
        if let v = payload["title"] as? String { drill.title = v }
        if let v = payload["focus"] as? String { drill.focus = v }
        if let v = payload["how"] as? String { drill.how = v }
        if let v = payload["durationSec"] as? Int { drill.durationSec = v }
        if let v = payload["sets"] as? Int { drill.sets = v }
        if let v = payload["coachingPoints"] as? [String] { drill.coachingPoints = v }
        if let v = payload["instructions"] as? [String] { drill.instructions = v }
        if let v = payload["equipment"] as? [String] { drill.equipment = v }
        if payload.keys.contains("space") { drill.space = payload["space"] as? String }
        if payload.keys.contains("videoURL") { drill.videoURL = payload["videoURL"] as? String }
        if payload.keys.contains("imageURL") { drill.imageURL = payload["imageURL"] as? String }
    }

    /// Undo a cached edit's content effect when it is reverted/deactivated.
    private static func undo(_ cached: CurriculumEditCache, context: ModelContext) {
        let drills = (try? context.fetch(FetchDescriptor<Drill>())) ?? []
        guard let drill = drills.first(where: { $0.id == cached.drillID }) else { return }
        switch cached.kind {
        case "hide":
            drill.isCoachHidden = false
        case "edit":
            if let dto = SeedData.bundledDrillDTO(id: cached.drillID) {
                SeedData.restoreDrill(drill, from: dto)
            }
        case "new":
            // Remove the coach-authored drill from its level. Player history rows
            // (SessionLogEntry) are independent and remain untouched.
            for discipline in (try? context.fetch(FetchDescriptor<Discipline>())) ?? [] {
                for category in discipline.categories {
                    for level in category.levels {
                        level.drills.removeAll { $0.id == cached.drillID }
                    }
                }
            }
            context.delete(drill)
        default:
            break
        }
    }
}
