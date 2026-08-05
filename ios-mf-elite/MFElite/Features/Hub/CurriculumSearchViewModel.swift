//
//  CurriculumSearchViewModel.swift
//  MFElite
//
//  Flattens the curriculum into a searchable list of drills.
//

import Foundation
import Observation

/// Equipment-based curriculum filter.
enum EquipmentFilter {
    case none, ballOnly
}

/// Total-time curriculum filter (durationSec × sets).
enum TimeFilter {
    case under5, mid, long
}

/// A single drill result with its full parent chain for breadcrumb context.
struct SearchResult: Identifiable {
    let id: String          // drill ID
    let drill: Drill
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline

    /// Relevance bucket — lower sorts first.
    let rank: Int
    /// Position in curriculum order (discipline → category → level → drill).
    /// Used as a stable tie-breaker: with an empty query every result has the
    /// same rank, and Swift's `sorted` is NOT stable, so without this the
    /// browse list came back in an arbitrary order that changed between runs.
    let order: Int
}

/// Derives filtered search results from the curriculum.
@MainActor
@Observable
final class CurriculumSearchViewModel {
    let disciplines: [Discipline]

    var searchText: String = ""
    var selectedDiscipline: Discipline?
    var equipmentFilter: EquipmentFilter?
    var timeFilter: TimeFilter?

    init(
        disciplines: [Discipline],
        searchText: String = "",
        selectedDiscipline: Discipline? = nil,
        equipmentFilter: EquipmentFilter? = nil,
        timeFilter: TimeFilter? = nil
    ) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.searchText = searchText
        self.selectedDiscipline = selectedDiscipline
        self.equipmentFilter = equipmentFilter
        self.timeFilter = timeFilter
    }

    /// Whether the given drill satisfies the active equipment filter.
    func matchesEquipment(_ d: Drill, _ f: EquipmentFilter) -> Bool {
        let gear = d.equipment.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        switch f {
        case .none:
            return gear.isEmpty
        case .ballOnly:
            return gear.count == 1 && gear[0].lowercased().contains("ball")
        }
    }

    /// Whether the given drill satisfies the active time filter.
    func matchesTime(_ d: Drill, _ f: TimeFilter) -> Bool {
        let total = d.durationSec * d.sets
        switch f {
        case .under5: return total < 300
        case .mid: return total >= 300 && total <= 600
        case .long: return total > 600
        }
    }

    /// Total drill count across the entire curriculum.
    var totalDrills: Int {
        disciplines.reduce(0) { partial, discipline in
            partial + discipline.categories.reduce(0) { sub, category in
                sub + category.levels.reduce(0) { $0 + $1.drills.count }
            }
        }
    }

    /// Drill count for a single discipline.
    func drillCount(for discipline: Discipline) -> Int {
        discipline.categories.reduce(0) { sub, category in
            sub + category.levels.reduce(0) { $0 + $1.drills.count }
        }
    }

    /// Whether the trimmed search query has content.
    var hasQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Searches the flattened curriculum, honoring the active discipline filter.
    func searchDrills() -> [SearchResult] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let scoped = selectedDiscipline.map { [$0] } ?? disciplines

        var results: [SearchResult] = []
        var order = 0

        for discipline in scoped.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            for category in discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                for level in category.levels.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                    for drill in level.drills.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                        order += 1
                        if let equipmentFilter, !matchesEquipment(drill, equipmentFilter) { continue }
                        if let timeFilter, !matchesTime(drill, timeFilter) { continue }

                        guard let rank = relevance(
                            query: query,
                            drill: drill,
                            category: category,
                            discipline: discipline
                        ) else { continue }

                        results.append(
                            SearchResult(
                                id: drill.id,
                                drill: drill,
                                level: level,
                                category: category,
                                discipline: discipline,
                                rank: rank,
                                order: order
                            )
                        )
                    }
                }
            }
        }

        return results.sorted {
            $0.rank == $1.rank ? $0.order < $1.order : $0.rank < $1.rank
        }
    }

    /// Returns a relevance bucket if the drill matches, otherwise nil.
    /// 0 = title match, 1 = focus match, 2 = other (coaching points / category / discipline).
    private func relevance(
        query: String,
        drill: Drill,
        category: Category,
        discipline: Discipline
    ) -> Int? {
        // Empty query (filter-only browse) matches everything.
        guard !query.isEmpty else { return 0 }

        if drill.title.lowercased().contains(query) { return 0 }
        if drill.focus.lowercased().contains(query) { return 1 }

        let coaching = drill.coachingPoints.joined(separator: " ").lowercased()
        if coaching.contains(query)
            || category.name.lowercased().contains(query)
            || discipline.name.lowercased().contains(query) {
            return 2
        }

        return nil
    }
}
