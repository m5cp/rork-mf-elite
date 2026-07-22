//
//  AppConfigStore.swift
//  MFElite
//
//  Remote app configuration + content naming overrides. Everyone reads;
//  only head coaches write (RLS-enforced). Values cache in UserDefaults so
//  names are stable offline and on cold launch. Refreshed on launch and
//  foreground alongside the other feeds.
//

import Foundation

@MainActor
@Observable
final class AppConfigStore {
    static let shared = AppConfigStore()

    private static let configCacheKey = "MF_APP_CONFIG_CACHE"      // [key: jsonString]
    static let overridesCacheKey = "MF_NAME_OVERRIDES"             // ["kind|target_id": name]

    private(set) var config: [String: String] = [:]
    private(set) var overrides: [String: String] = [:]

    private init() {
        config = (UserDefaults.standard.dictionary(forKey: Self.configCacheKey) as? [String: String]) ?? [:]
        overrides = (UserDefaults.standard.dictionary(forKey: Self.overridesCacheKey) as? [String: String]) ?? [:]
    }

    /// The award title (default "MF Elite MVP"; head-coach editable).
    var awardTitle: String {
        let value = config["award_title"] ?? "MF Elite MVP"
        return value.isEmpty ? "MF Elite MVP" : value
    }

    /// Display-name override for a content item, or nil when unchanged.
    func overrideName(kind: String, id: String) -> String? {
        overrides["\(kind)|\(id)"]
    }

    /// Rank title override by rank raw value (XP threshold as string id).
    func rankTitle(default defaultTitle: String, rankID: String) -> String {
        overrideName(kind: "rank", id: rankID) ?? defaultTitle
    }

    func refresh() async {
        if let rows = await SupabaseClient.shared.get(table: "app_config", query: []) {
            var fresh: [String: String] = [:]
            for row in rows {
                guard let key = row["key"] as? String else { continue }
                if let string = row["value"] as? String {
                    fresh[key] = string
                } else if let value = row["value"] {
                    fresh[key] = "\(value)"
                }
            }
            config = fresh
            UserDefaults.standard.set(fresh, forKey: Self.configCacheKey)
        }
        if let rows = await SupabaseClient.shared.get(table: "content_overrides", query: []) {
            var fresh: [String: String] = [:]
            for row in rows {
                guard let kind = row["kind"] as? String,
                      let target = row["target_id"] as? String,
                      let name = row["name"] as? String, !name.isEmpty else { continue }
                fresh["\(kind)|\(target)"] = name
            }
            overrides = fresh
            UserDefaults.standard.set(fresh, forKey: Self.overridesCacheKey)
        }
    }

    // MARK: - Head coach writes

    /// Save a rename. Returns true on success; audit-logged.
    @discardableResult
    func saveOverride(kind: String, targetID: String, name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var row: [String: Any] = ["kind": kind, "target_id": targetID, "name": trimmed]
        if let uid = SupabaseAuth.shared.userID { row["updated_by"] = uid }
        let ok = await SupabaseClient.shared.upsert(table: "content_overrides", values: row, onConflict: "kind,target_id")
        if ok {
            overrides["\(kind)|\(targetID)"] = trimmed
            UserDefaults.standard.set(overrides, forKey: Self.overridesCacheKey)
            await audit(action: "rename", detail: ["kind": kind, "target_id": targetID, "name": trimmed])
        }
        return ok
    }

    /// Remove a rename (revert to the built-in name).
    func clearOverride(kind: String, targetID: String) async {
        _ = await SupabaseClient.shared.delete(table: "content_overrides",
                                                match: ["kind": kind, "target_id": targetID])
        overrides.removeValue(forKey: "\(kind)|\(targetID)")
        UserDefaults.standard.set(overrides, forKey: Self.overridesCacheKey)
        await audit(action: "rename_cleared", detail: ["kind": kind, "target_id": targetID])
    }

    /// Save an app_config value (e.g. the award title). Audit-logged.
    @discardableResult
    func saveConfig(key: String, value: String) async -> Bool {
        var row: [String: Any] = ["key": key, "value": value]
        if let uid = SupabaseAuth.shared.userID { row["updated_by"] = uid }
        let ok = await SupabaseClient.shared.upsert(table: "app_config", values: row, onConflict: "key")
        if ok {
            config[key] = value
            UserDefaults.standard.set(config, forKey: Self.configCacheKey)
            await audit(action: "config", detail: ["key": key, "value": value])
        }
        return ok
    }

    func audit(action: String, detail: [String: Any]) async {
        guard let uid = SupabaseAuth.shared.userID else { return }
        _ = await SupabaseClient.shared.insert(table: "admin_audit", values: [
            "actor": uid, "action": action, "detail": detail
        ])
    }
}
