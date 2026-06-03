//
//  RankDetailViewModel.swift
//  MFElite
//
//  Derives the full XP breakdown for the current rank from the curriculum
//  and the player's mastery progress.
//

import Foundation
import Observation

/// A single labelled XP source row in the breakdown.
struct XPBreakdownRow: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let unitValue: Int
    var total: Int { count * unitValue }
    /// e.g. "12 × 25 = 300"
    var detail: String { "\(count) × \(unitValue.formatted()) = \(total.formatted())" }
}

@MainActor
@Observable
final class RankDetailViewModel {
    let disciplines: [Discipline]
    let xp: Int
    private let masteredDrillIDs: Set<String>

    init(disciplines: [Discipline], xp: Int, masteredDrillIDs: Set<String>) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.xp = xp
        self.masteredDrillIDs = masteredDrillIDs
    }

    // MARK: - Rank

    var currentRank: AcademyRank { AcademyRank.rank(for: xp) }
    var nextRank: AcademyRank? { AcademyRank.nextRank(for: xp) }
    var xpToNext: Int? { AcademyRank.xpToNext(for: xp) }

    var progressToNext: Double {
        guard let next = nextRank else { return 1 }
        let floorXP = currentRank.rawValue
        let span = next.rawValue - floorXP
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(xp - floorXP) / Double(span)))
    }

    // MARK: - Counts

    private var allDrills: [Drill] {
        disciplines.flatMap { $0.categories.flatMap { $0.levels.flatMap { $0.drills } } }
    }

    var masteredDrillCount: Int {
        allDrills.filter { masteredDrillIDs.contains($0.id) }.count
    }

    /// Levels where every drill is mastered.
    var masteredLevelCount: Int {
        disciplines.reduce(0) { partial, discipline in
            partial + discipline.categories.reduce(0) { sub, category in
                sub + category.levels.filter { isLevelMastered($0) }.count
            }
        }
    }

    /// Categories where every drill is mastered.
    var certCount: Int {
        disciplines.reduce(0) { $0 + $1.categories.filter { isCategoryCertified($0) }.count }
    }

    /// Disciplines where every category is certified.
    var diplomaCount: Int {
        disciplines.filter { isDisciplineComplete($0) }.count
    }

    // MARK: - Breakdown

    var breakdownRows: [XPBreakdownRow] {
        [
            XPBreakdownRow(label: "Drills completed", count: masteredDrillCount, unitValue: ProgressionRules.xpPerDrill),
            XPBreakdownRow(label: "Level bonuses", count: masteredLevelCount, unitValue: ProgressionRules.xpLevelBonus),
            XPBreakdownRow(label: "Certifications", count: certCount, unitValue: ProgressionRules.xpCategoryCert),
            XPBreakdownRow(label: "Discipline diplomas", count: diplomaCount, unitValue: ProgressionRules.xpDisciplineDiploma)
        ]
    }

    var breakdownTotal: Int {
        breakdownRows.reduce(0) { $0 + $1.total }
    }

    // MARK: - XP by discipline

    func xp(for discipline: Discipline) -> Int {
        let drills = discipline.categories.flatMap { $0.levels.flatMap { $0.drills } }
        let masteredDrills = drills.filter { masteredDrillIDs.contains($0.id) }.count
        let levels = discipline.categories.reduce(0) { $0 + $1.levels.filter { isLevelMastered($0) }.count }
        let certs = discipline.categories.filter { isCategoryCertified($0) }.count
        let diploma = isDisciplineComplete(discipline) ? 1 : 0

        return masteredDrills * ProgressionRules.xpPerDrill
            + levels * ProgressionRules.xpLevelBonus
            + certs * ProgressionRules.xpCategoryCert
            + diploma * ProgressionRules.xpDisciplineDiploma
    }

    // MARK: - Helpers

    private func isLevelMastered(_ level: MasteryLevel) -> Bool {
        let drills = level.drills
        guard !drills.isEmpty else { return false }
        return drills.allSatisfy { masteredDrillIDs.contains($0.id) }
    }

    private func isCategoryCertified(_ category: Category) -> Bool {
        let drills = category.levels.flatMap { $0.drills }
        guard !drills.isEmpty else { return false }
        return drills.allSatisfy { masteredDrillIDs.contains($0.id) }
    }

    private func isDisciplineComplete(_ discipline: Discipline) -> Bool {
        guard !discipline.categories.isEmpty else { return false }
        return discipline.categories.allSatisfy { isCategoryCertified($0) }
    }
}
