//
//  ProgressionRules.swift
//  MFElite
//

import Foundation

/// Central constants that govern XP rewards and progression gating. Values are
/// seeded with sensible defaults and persisted in `UserDefaults`. Content and
/// rule updates ship through App Store updates in V1. Read as
/// `ProgressionRules.freeLevels` etc.
enum ProgressionRules {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let xpPerDrill = "rules_xp_per_drill"
        static let xpLevelBonus = "rules_xp_level_bonus"
        static let xpCategoryCert = "rules_xp_category_cert"
        static let xpDisciplineDiploma = "rules_xp_discipline_diploma"
        static let freeLevels = "rules_free_levels"
        static let masteryPasses = "rules_mastery_passes"
    }

    // MARK: - Defaults (used until the first sync lands)

    static let defaultXpPerDrill = 25
    static let defaultXpLevelBonus = 120
    static let defaultXpCategoryCert = 400
    static let defaultXpDisciplineDiploma = 1500
    static let defaultFreeLevels = 1
    static let defaultMasteryPasses = 3

    // MARK: - Live values

    private static func value(_ key: String, _ fallback: Int) -> Int {
        let stored = defaults.integer(forKey: key)
        // `integer(forKey:)` returns 0 when unset; treat 0 mastery/levels as unset
        // so we never divide by an accidental zero before the first sync.
        return defaults.object(forKey: key) == nil || stored <= 0 ? fallback : stored
    }

    static var xpPerDrill: Int { value(Key.xpPerDrill, defaultXpPerDrill) }
    static var xpLevelBonus: Int { value(Key.xpLevelBonus, defaultXpLevelBonus) }
    static var xpCategoryCert: Int { value(Key.xpCategoryCert, defaultXpCategoryCert) }
    static var xpDisciplineDiploma: Int { value(Key.xpDisciplineDiploma, defaultXpDisciplineDiploma) }
    static var masteryPasses: Int { value(Key.masteryPasses, defaultMasteryPasses) }

    /// Free-tier level cap. `freeLevels` may legitimately be set to higher values
    /// by the coach; 0 is not allowed (at least level 1 is always free).
    static var freeLevels: Int {
        guard defaults.object(forKey: Key.freeLevels) != nil else { return defaultFreeLevels }
        return max(1, defaults.integer(forKey: Key.freeLevels))
    }

    // MARK: - Persistence

    /// Persist updated progression rules into the local store.
    static func apply(
        xpPerDrill: Int,
        xpLevelBonus: Int,
        xpCategoryCert: Int,
        xpDisciplineDiploma: Int,
        freeLevels: Int,
        masteryPasses: Int
    ) {
        defaults.set(xpPerDrill, forKey: Key.xpPerDrill)
        defaults.set(xpLevelBonus, forKey: Key.xpLevelBonus)
        defaults.set(xpCategoryCert, forKey: Key.xpCategoryCert)
        defaults.set(xpDisciplineDiploma, forKey: Key.xpDisciplineDiploma)
        defaults.set(max(1, freeLevels), forKey: Key.freeLevels)
        defaults.set(masteryPasses, forKey: Key.masteryPasses)
    }
}
