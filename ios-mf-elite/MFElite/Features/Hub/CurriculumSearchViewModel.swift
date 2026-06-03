//
//  CurriculumSearchViewModel.swift
//  MFElite
//
//  Flattens the curriculum into a searchable list of drills.
//

import Foundation
import Observation

/// A single drill result with its full parent chain for breadcrumb context.
struct SearchResult: Identifiable {
    let id: String          // drill ID
    let drill: Drill
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline

    /// Relevance bucket — lower sorts first.
    let rank: Int
}

/// Derives filtered search results from the curriculum.
@MainActor
@Observable
final class CurriculumSearchViewModel {
    let disciplines: [Discipline]

    var searchText: String = ""
    var selectedDiscipline: Discipline?

    init(disciplines: [Discipline], searchText: String = "", selectedDiscipline: Discipline? = nil) {
        self.disciplines = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.searchText = searchText
        self.selectedDiscipline = selectedDiscipline
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

        for discipline in scoped.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            for category in discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                for level in category.levels.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                    for drill in level.drills.sorted(by: { $0.sortIndex < $1.sortIndex }) {
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
                                rank: rank
                            )
                        )
                    }
                }
            }
        }

        return results.sorted { $0.rank < $1.rank }
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
