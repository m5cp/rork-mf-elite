//
//  CoachStandardsStore.swift
//  MFElite
//
//  The head coach's own combine baseline: which tests make up the academy's
//  baseline test, and the target number he expects at each age group. Everyone
//  reads; only head coaches write (RLS-enforced). Values cache in UserDefaults
//  so a player's targets survive a cold launch with no network, exactly like
//  `AppConfigStore` does for content names.
//
//  This never replaces the bundled male/female standards in
//  `combine-benchmarks.json` — it layers on top of them. A test with no coach
//  target still grades against the published scale, and the editor shows the
//  coach that scale next to his own number so he can see what he is deviating
//  from.
//

import Foundation

/// Where a resolved target number came from.
enum CoachStandardSource {
    /// The head coach typed this number for this test and age group.
    case coachTarget
    /// Derived from the bundled male/female benchmark scale.
    case defaultStandard
}

/// A target a player is measured against, plus where it came from so the UI can
/// say so out loud rather than presenting a coach's number as a national one.
struct CoachStandardTarget {
    let value: Double
    let source: CoachStandardSource
    let bandID: String
    let bandLabel: String
}

@MainActor
@Observable
final class CoachStandardsStore {
    static let shared = CoachStandardsStore()

    private static let baselineCacheKey = "MF_COACH_BASELINE_EXCLUDED"  // [testID]
    private static let targetsCacheKey  = "MF_COACH_STANDARD_TARGETS"   // ["testID|bandID": Double]

    /// How long a refresh stays fresh. The baseline changes about as often as a
    /// season does, so re-fetching on every appearance would be pure noise.
    private static let staleAfter: TimeInterval = 300

    /// Tests the head coach has deliberately taken OUT of the baseline.
    ///
    /// Absence is the default, not presence: with no rows at all — a fresh
    /// install, an offline launch, a database that has never been written to —
    /// every seeded test is in the baseline, which is exactly today's behaviour.
    private(set) var excludedTestIDs: Set<String> = []

    /// Coach targets keyed "testID|bandID".
    private(set) var targets: [String: Double] = [:]

    private var lastRefresh: Date?
    private var isRefreshing = false

    private init() {
        excludedTestIDs = Set(UserDefaults.standard.stringArray(forKey: Self.baselineCacheKey) ?? [])
        targets = Self.decodeTargets(UserDefaults.standard.dictionary(forKey: Self.targetsCacheKey))
    }

    // MARK: - Reading

    /// Whether a test counts toward "the baseline". Tests outside it stay fully
    /// available on their own — this only decides what a completed combine means.
    func isInBaseline(_ testID: String) -> Bool {
        !excludedTestIDs.contains(testID)
    }

    /// The subset of `tests` the head coach has kept in the baseline, in order.
    func baseline(from tests: [CombineTest]) -> [CombineTest] {
        tests.filter { isInBaseline($0.id) }
    }

    /// The coach's own target for a test at an age group, or nil when he has not
    /// set one and the published standard still applies.
    func coachTarget(testID: String, bandID: String) -> Double? {
        targets["\(testID)|\(bandID)"]
    }

    /// True when the coach has set at least one target anywhere. Used to decide
    /// whether to mention coach standards at all to a player.
    var hasAnyTarget: Bool { !targets.isEmpty }

    /// The published standard used as the target when the coach has not set one.
    ///
    /// The benchmark file gives four cut points per scale — the entries to Club,
    /// Competitive, Elite and Pro-Level. We take the Competitive entry: it is the
    /// middle of the five tiers, it is the number a serious club player should be
    /// chasing rather than a professional one, and Elite and Pro stay visible
    /// above it on the same bar as stretch. Picking Elite here would have made
    /// every default target read as a failure for most of the roster.
    private static let defaultTierIndex = 1

    /// The default target for a test on the player's own scale, or nil when the
    /// test has no published benchmark (a coach-invented test, say).
    func defaultTarget(testID: String, bandID: String, female: Bool) -> Double? {
        guard let boundaries = CombineBenchmarks.shared.boundaries(testID: testID, bandID: bandID, female: female),
              boundaries.count > Self.defaultTierIndex else { return nil }
        return boundaries[Self.defaultTierIndex]
    }

    /// Resolve the number a player is aiming at: the coach's target for this age
    /// group when he set one, otherwise the published standard for the player's
    /// scale. Returns nil when neither exists, so callers can simply show nothing.
    func resolvedTarget(testID: String, band: CombineBenchmarks.AgeBand, female: Bool) -> CoachStandardTarget? {
        if let coach = coachTarget(testID: testID, bandID: band.id) {
            return CoachStandardTarget(value: coach, source: .coachTarget,
                                       bandID: band.id, bandLabel: band.label)
        }
        if let standard = defaultTarget(testID: testID, bandID: band.id, female: female) {
            return CoachStandardTarget(value: standard, source: .defaultStandard,
                                       bandID: band.id, bandLabel: band.label)
        }
        return nil
    }

    /// Whether `value` has reached `target`, remembering that on a timed event a
    /// smaller number is the better one.
    static func meets(value: Double, target: Double, lowerIsBetter: Bool) -> Bool {
        lowerIsBetter ? value <= target : value >= target
    }

    // MARK: - Refresh

    /// Pull the baseline and targets. Both tables are tiny (at most one row per
    /// test, and one per test/age-group pair), so this is a pair of unfiltered
    /// reads rather than anything cleverer.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var fetched = false

        if let rows = await SupabaseClient.shared.get(table: "coach_baseline_tests", query: []) {
            fetched = true
            var excluded: Set<String> = []
            for row in rows {
                guard let testID = row["test_id"] as? String else { continue }
                // A row that fails to say otherwise is an included row.
                let included = (row["included"] as? Bool) ?? true
                if !included { excluded.insert(testID) }
            }
            excludedTestIDs = excluded
            UserDefaults.standard.set(Array(excluded), forKey: Self.baselineCacheKey)
        }

        if let rows = await SupabaseClient.shared.get(table: "coach_standards", query: []) {
            fetched = true
            var fresh: [String: Double] = [:]
            for row in rows {
                guard let testID = row["test_id"] as? String,
                      let bandID = row["age_band"] as? String,
                      let value = Self.double(row["target"]) else { continue }
                fresh["\(testID)|\(bandID)"] = value
            }
            targets = fresh
            UserDefaults.standard.set(fresh, forKey: Self.targetsCacheKey)
        }

        // Only start the staleness clock on a fetch that actually landed —
        // otherwise one launch with no signal locks the cached copy in for the
        // next five minutes of a session the player is right in the middle of.
        if fetched { lastRefresh = Date() }
    }

    /// Refresh only when the cached copy has gone stale. Safe to call from any
    /// `.task` that displays standards.
    func refreshIfStale() async {
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < Self.staleAfter { return }
        await refresh()
    }

    // MARK: - Head coach writes

    /// Put a test into the baseline or take it out. Returns true on success;
    /// a non-head-coach write is refused by RLS and returns false.
    @discardableResult
    func setIncluded(testID: String, included: Bool) async -> Bool {
        var row: [String: Any] = ["test_id": testID, "included": included]
        if let uid = SupabaseAuth.shared.userID { row["updated_by"] = uid }
        let ok = await SupabaseClient.shared.upsert(table: "coach_baseline_tests",
                                                    values: row, onConflict: "test_id")
        if ok {
            if included {
                excludedTestIDs.remove(testID)
            } else {
                excludedTestIDs.insert(testID)
            }
            UserDefaults.standard.set(Array(excludedTestIDs), forKey: Self.baselineCacheKey)
            await AppConfigStore.shared.audit(
                action: "combine_baseline",
                detail: ["test_id": testID, "included": included]
            )
        }
        return ok
    }

    /// Set the coach's target for a test at one age group.
    @discardableResult
    func setTarget(testID: String, bandID: String, value: Double) async -> Bool {
        guard value > 0, value.isFinite, value < 1_000_000 else { return false }
        var row: [String: Any] = ["test_id": testID, "age_band": bandID, "target": value]
        if let uid = SupabaseAuth.shared.userID { row["updated_by"] = uid }
        let ok = await SupabaseClient.shared.upsert(table: "coach_standards",
                                                    values: row, onConflict: "test_id,age_band")
        if ok {
            targets["\(testID)|\(bandID)"] = value
            UserDefaults.standard.set(targets, forKey: Self.targetsCacheKey)
            await AppConfigStore.shared.audit(
                action: "combine_target",
                detail: ["test_id": testID, "age_band": bandID, "target": value]
            )
        }
        return ok
    }

    /// Drop the coach's target so the published standard applies again.
    ///
    /// Uses the counting delete: PostgREST answers a DELETE that RLS filtered to
    /// nothing with the same 204 as a real one, so a regular coach clearing a
    /// target would otherwise watch it vanish locally and come back on refresh.
    @discardableResult
    func clearTarget(testID: String, bandID: String) async -> Bool {
        let deleted = await SupabaseClient.shared.deleteCounting(
            table: "coach_standards",
            match: ["test_id": testID, "age_band": bandID]
        )
        guard let deleted, deleted > 0 else { return false }
        targets.removeValue(forKey: "\(testID)|\(bandID)")
        UserDefaults.standard.set(targets, forKey: Self.targetsCacheKey)
        await AppConfigStore.shared.audit(
            action: "combine_target_cleared",
            detail: ["test_id": testID, "age_band": bandID]
        )
        return true
    }

    // MARK: - Decoding helpers

    /// PostgREST hands numerics back as JSON numbers, but a column type change or
    /// a very large value can arrive as a string. Accept both rather than
    /// silently dropping a target the coach can see in the database.
    private static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }

    private static func decodeTargets(_ raw: [String: Any]?) -> [String: Double] {
        guard let raw else { return [:] }
        var out: [String: Double] = [:]
        for (key, value) in raw {
            if let number = double(value) { out[key] = number }
        }
        return out
    }
}
