//
//  CertificationsViewModel.swift
//  MFElite
//

import Foundation
import Observation

/// The state of a single skill certification.
enum CertState: Equatable {
    case earned
    case inProgress(done: Int, total: Int)
    case notStarted
    case locked
}

/// Derives the certifications gallery from the curriculum and player mastery.
@MainActor
@Observable
final class CertificationsViewModel {
    let disciplines: [Discipline]

    /// Drill IDs the player has mastered.
    private let masteredDrillIDs: Set<String>

    init(disciplines: [Discipline], masteredDrillIDs: Set<String>) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.masteredDrillIDs = masteredDrillIDs
    }

    /// Categories in a discipline, sorted by sortIndex.
    func categories(for discipline: Discipline) -> [Category] {
        discipline.categories.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// A category is certified when every drill in every level is mastered.
    func isCertified(_ category: Category) -> Bool {
        let drills = category.levels.flatMap { $0.drills }
        guard !drills.isEmpty else { return false }
        return drills.allSatisfy { masteredDrillIDs.contains($0.id) }
    }

    /// The certification state for a category.
    func certState(_ category: Category) -> CertState {
        let levels = category.levels.sorted { $0.number < $1.number }
        let totalLevels = levels.count
        guard totalLevels > 0 else { return .notStarted }

        if isCertified(category) { return .earned }

        let masteredLevels = levels.filter { level in
            !level.drills.isEmpty && level.drills.allSatisfy { masteredDrillIDs.contains($0.id) }
        }.count

        let anyProgress = category.levels
            .flatMap { $0.drills }
            .contains { masteredDrillIDs.contains($0.id) }

        if anyProgress {
            return .inProgress(done: masteredLevels, total: totalLevels)
        }
        return .notStarted
    }

    /// Total certifications earned across all disciplines.
    var earnedCount: Int {
        disciplines.reduce(0) { partial, discipline in
            partial + discipline.categories.filter { isCertified($0) }.count
        }
    }

    /// Total number of certifications in the curriculum.
    var totalCount: Int {
        disciplines.reduce(0) { $0 + $1.categories.count }
    }
}
