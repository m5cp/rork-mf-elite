//
//  DrillLibraryView.swift
//  MFElite
//
//  A flat, browsable list of every drill in the curriculum, grouped by
//  discipline, with discipline + mastery-state filters.
//

import SwiftUI
import SwiftData

/// Navigation route to the flat drill library.
struct DrillLibraryRoute: Hashable {}

/// Mastery filter applied to the library.
private enum LibraryFilter: Hashable {
    case all
    case discipline(String) // discipline id
    case mastered
    case inProgress
    case notStarted
}

/// A resolved drill carrying its full navigation context and progress state.
private struct LibraryEntry: Identifiable {
    let drill: Drill
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline
    let passes: Int
    let isMastered: Bool

    var id: String { drill.id }
    var isInProgress: Bool { passes > 0 && !isMastered }
    var isNotStarted: Bool { passes == 0 && !isMastered }
}

/// One discipline section of resolved entries.
private struct LibrarySection: Identifiable {
    let discipline: Discipline
    let entries: [LibraryEntry]
    var id: String { discipline.id }
}

struct DrillLibraryView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var progress: [DrillProgress]

    @State private var filter: LibraryFilter = .all

    private var passesByDrill: [String: Int] {
        Dictionary(progress.map { ($0.drillID, $0.passesLogged) }, uniquingKeysWith: { a, _ in a })
    }

    private var masteredIDs: Set<String> {
        Set(progress.filter { $0.isMastered }.map { $0.drillID })
    }

    /// All entries resolved from the curriculum, in canonical order.
    private var allEntries: [LibraryEntry] {
        var result: [LibraryEntry] = []
        for discipline in disciplines.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            for category in discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                for level in category.levels.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                    for drill in level.drills.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                        result.append(LibraryEntry(
                            drill: drill,
                            level: level,
                            category: category,
                            discipline: discipline,
                            passes: passesByDrill[drill.id] ?? 0,
                            isMastered: masteredIDs.contains(drill.id)
                        ))
                    }
                }
            }
        }
        return result
    }

    private var filteredEntries: [LibraryEntry] {
        switch filter {
        case .all:                     return allEntries
        case .discipline(let id):      return allEntries.filter { $0.discipline.id == id }
        case .mastered:                return allEntries.filter { $0.isMastered }
        case .inProgress:              return allEntries.filter { $0.isInProgress }
        case .notStarted:              return allEntries.filter { $0.isNotStarted }
        }
    }

    private var sections: [LibrarySection] {
        let entries = filteredEntries
        return disciplines.sorted(by: { $0.sortIndex < $1.sortIndex }).compactMap { discipline in
            let group = entries.filter { $0.discipline.id == discipline.id }
            guard !group.isEmpty else { return nil }
            return LibrarySection(discipline: discipline, entries: group)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                filterBar
                listContent
                countsFooter
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Drill Library")
            Text("All Drills")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("\(allEntries.count) drills across \(totalCategories) categories")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private var totalCategories: Int {
        disciplines.reduce(0) { $0 + $1.categories.count }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s8) {
                Chip(label: "All", active: filter == .all) { filter = .all }
                ForEach(disciplines.sorted(by: { $0.sortIndex < $1.sortIndex })) { discipline in
                    Chip(label: discipline.name, active: filter == .discipline(discipline.id)) {
                        filter = .discipline(discipline.id)
                    }
                }
                Chip(label: "Mastered", active: filter == .mastered) { filter = .mastered }
                Chip(label: "In Progress", active: filter == .inProgress) { filter = .inProgress }
                Chip(label: "Not Started", active: filter == .notStarted) { filter = .notStarted }
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .padding(.top, DS.Spacing.s12)
    }

    // MARK: - List

    @ViewBuilder
    private var listContent: some View {
        if sections.isEmpty {
            Text("No drills match this filter yet.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s48)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    sectionHeader(section.discipline)

                    ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                        NavigationLink(value: DrillRoute(
                            discipline: entry.discipline,
                            category: entry.category,
                            level: entry.level,
                            drill: entry.drill
                        )) {
                            LibraryDrillRow(entry: entry, isLast: index == section.entries.count - 1)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
            .padding(.top, DS.Spacing.s16)
        }
    }

    private func sectionHeader(_ discipline: Discipline) -> some View {
        HStack(spacing: DS.Spacing.s8) {
            DisciplineMark(kind: discipline.mark, size: 16)
            Text(discipline.name)
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
        .padding(.bottom, DS.Spacing.s8)
    }

    // MARK: - Counts footer

    private var countsFooter: some View {
        let mastered = allEntries.filter { $0.isMastered }.count
        let inProgress = allEntries.filter { $0.isInProgress }.count
        let notStarted = allEntries.filter { $0.isNotStarted }.count
        return Text("\(mastered) MASTERED · \(inProgress) IN PROGRESS · \(notStarted) NOT STARTED")
            .style(.microSm)
            .foregroundStyle(DS.Colors.Ink.quaternary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s32)
    }
}

// MARK: - LibraryDrillRow

private struct LibraryDrillRow: View {
    let entry: LibraryEntry
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: DS.Spacing.s16) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Text(entry.drill.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)

                    HStack(spacing: DS.Spacing.s8) {
                        Text(entry.drill.focus)
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                        Text("· \(entry.category.name)")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }

                    masteryDots
                }

                Spacer(minLength: DS.Spacing.s8)

                trailingIndicator
            }
            .padding(.vertical, DS.Spacing.s12 + 2)

            if !isLast {
                Hairline()
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .contentShape(Rectangle())
    }

    private var masteryDots: some View {
        HStack(spacing: DS.Spacing.s4) {
            ForEach(0..<ProgressionRules.masteryPasses, id: \.self) { index in
                Circle()
                    .fill(index < entry.passes ? Color.white : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(index < entry.passes ? Color.clear : DS.Colors.Line.subtle, lineWidth: 1)
                    )
            }
        }
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        if entry.isMastered {
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                )
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
    }
}

#Preview {
    NavigationStack {
        DrillLibraryView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [
        Discipline.self, Category.self, MasteryLevel.self,
        Drill.self, DrillProgress.self, PlayerState.self
    ])
}
