//
//  WorkoutBuilderView.swift
//  MFElite
//
//  Build or edit a custom workout from any drills in the curriculum. The
//  selected drills run back-to-back exactly like a curated routine.
//

import SwiftUI
import SwiftData

/// One selected drill in the builder. Wraps a drill ID with a stable identity so
/// the same drill can appear more than once (repeat blocks) and reorder cleanly.
private struct BuilderItem: Identifiable, Equatable {
    let id = UUID()
    let drillID: String
}

/// Reference-type memo for the drillID→context map so it isn't rebuilt on every
/// keystroke / reorder while editing a workout.
private final class BuilderIndexCache {
    var signature: Int = -1
    var index: [String: DrillContext] = [:]
}

struct WorkoutBuilderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]

    /// The workout being edited, or nil when creating a new one.
    let editing: CustomWorkout?

    @State private var title: String
    @State private var items: [BuilderItem]
    @State private var showPicker = false
    @State private var indexCache = BuilderIndexCache()

    private let titleLimit = 30

    init(editing: CustomWorkout? = nil) {
        self.editing = editing
        _title = State(initialValue: editing?.title ?? "My Workout")
        _items = State(initialValue: (editing?.drillIDs ?? []).map { BuilderItem(drillID: $0) })
    }

    /// drillID → resolved context. Memoized so it's only rebuilt when the
    /// curriculum graph identity changes, not on every body evaluation.
    private var index: [String: DrillContext] {
        let signature = disciplines.map { ObjectIdentifier($0) }.hashValue
        if indexCache.signature != signature {
            var map: [String: DrillContext] = [:]
            for discipline in disciplines {
                for category in discipline.categories {
                    for level in category.levels {
                        for drill in level.drills {
                            map[drill.id] = DrillContext(
                                drill: drill, level: level, category: category, discipline: discipline
                            )
                        }
                    }
                }
            }
            indexCache.index = map
            indexCache.signature = signature
        }
        return indexCache.index
    }

    private var resolvedDrills: [Drill] {
        items.compactMap { index[$0.drillID]?.drill }
    }

    private var canSave: Bool {
        items.count >= 2 && !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                DS.Colors.Bg.base.ignoresSafeArea()

                List {
                    nameSection
                    drillsSection
                    Section { Color.clear.frame(height: 80).listRowBackground(Color.clear) }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))

                bottomBar
            }
            .navigationTitle(editing == nil ? "New Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .foregroundStyle(canSave ? DS.Colors.Ink.primary : DS.Colors.Ink.quaternary)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showPicker) {
                DrillPickerView(disciplines: disciplines) { drillID in
                    items.append(BuilderItem(drillID: drillID))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            TextField("Workout name", text: $title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.primary)
                .onChange(of: title) { _, newValue in
                    if newValue.count > titleLimit {
                        title = String(newValue.prefix(titleLimit))
                    }
                }
                .listRowBackground(DS.Colors.Bg.card)
        } header: {
            Text("Name")
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
    }

    @ViewBuilder
    private var drillsSection: some View {
        Section {
            if items.isEmpty {
                Text("No drills yet. Tap “Add drills” below to pick from the academy — they’ll run back-to-back in the order you set.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(DS.Colors.Bg.card)
            } else {
                ForEach(items) { item in
                    if let ctx = index[item.drillID] {
                        drillRow(ctx)
                            .listRowBackground(DS.Colors.Bg.card)
                    }
                }
                .onMove { source, destination in
                    items.move(fromOffsets: source, toOffset: destination)
                }
                .onDelete { offsets in
                    items.remove(atOffsets: offsets)
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPicker = true
            } label: {
                HStack(spacing: DS.Spacing.s8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Add drills")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(DS.Colors.Ink.primary)
            }
            .listRowBackground(DS.Colors.Bg.card)
        } header: {
            Text("Drills")
                .foregroundStyle(DS.Colors.Ink.tertiary)
        } footer: {
            if items.count < 2 {
                Text("Add at least 2 drills to save.")
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            } else {
                Text("Drills run back-to-back, top to bottom. Drag to reorder.")
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
    }

    private func drillRow(_ ctx: DrillContext) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            DisciplineMark(kind: ctx.discipline.mark, size: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(ctx.drill.title)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("\(ctx.drill.focus) · \(ctx.drill.durationSec / 60) min")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(items.count) \(items.count == 1 ? "drill" : "drills")")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("~\(estimatedSessionMinutes(forDrills: resolvedDrills)) min")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.vertical, DS.Spacing.s12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Hairline() }
    }

    // MARK: - Save

    private func save() {
        guard canSave else { return }
        let drillIDs = items.map(\.drillID)
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if let editing {
            editing.title = trimmed
            editing.drillIDs = drillIDs
            editing.updatedAt = Date()
        } else {
            let workout = CustomWorkout(title: trimmed, drillIDs: drillIDs)
            context.insert(workout)
        }
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Drill picker

/// A searchable, grouped picker that adds drills to the workout being built.
private struct DrillPickerView: View {
    let disciplines: [Discipline]
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var addedCount = 0

    private var viewModel: CurriculumSearchViewModel {
        CurriculumSearchViewModel(disciplines: disciplines, searchText: searchText)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                DS.Colors.Bg.base.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if hasQuery {
                            let results = viewModel.searchDrills()
                            if results.isEmpty {
                                emptyState
                            } else {
                                ForEach(results) { result in
                                    pickerRow(
                                        drill: result.drill,
                                        discipline: result.discipline,
                                        breadcrumb: "\(result.discipline.name) · \(result.category.name)"
                                    )
                                    Hairline().padding(.horizontal, DS.Spacing.s20)
                                }
                            }
                        } else {
                            groupedBrowse
                        }
                    }
                    .padding(.bottom, 80)
                }
                .scrollIndicators(.hidden)

                if addedCount > 0 { addedBar }
            }
            .navigationTitle("Add drills")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search drills...")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var hasQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var groupedBrowse: some View {
        ForEach(disciplines) { discipline in
            Section {
                ForEach(discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex })) { category in
                    let drills = category.levels
                        .sorted(by: { $0.sortIndex < $1.sortIndex })
                        .flatMap { $0.drills.sorted(by: { $0.sortIndex < $1.sortIndex }) }
                    if !drills.isEmpty {
                        Text(category.name.uppercased())
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .padding(.horizontal, DS.Spacing.s20)
                            .padding(.top, DS.Spacing.s12)
                            .padding(.bottom, DS.Spacing.s4)
                        ForEach(drills) { drill in
                            pickerRow(drill: drill, discipline: discipline, breadcrumb: category.name)
                            Hairline().padding(.horizontal, DS.Spacing.s20)
                        }
                    }
                }
            } header: {
                HStack(spacing: DS.Spacing.s8) {
                    DisciplineMark(kind: discipline.mark, size: 16)
                    Text(discipline.name)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s20)
            }
        }
    }

    private func pickerRow(drill: Drill, discipline: Discipline, breadcrumb: String) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(drill.title)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text("\(breadcrumb) · \(drill.durationSec / 60) min")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            Spacer(minLength: DS.Spacing.s8)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onAdd(drill.id)
                addedCount += 1
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.s12)
        .padding(.horizontal, DS.Spacing.s20)
    }

    private var addedBar: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("\(addedCount) added")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DS.Colors.Ink.primary)
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DS.Colors.Ground.primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 18)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.vertical, DS.Spacing.s12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Hairline() }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.s12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(DS.Colors.Ink.quaternary)
            Text("No drills found")
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
