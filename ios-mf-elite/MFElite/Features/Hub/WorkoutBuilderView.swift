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
    /// When set, the builder publishes instead of saving a local CustomWorkout:
    /// it shows a note field, caps drills at 8, and hands (title, note, drillIDs)
    /// to this closure. Used by Coach Mode to publish a featured workout.
    let onPublish: ((String, String, [String]) -> Void)?

    @State private var title: String
    @State private var note: String
    @State private var items: [BuilderItem]
    @State private var showPicker = false
    @State private var indexCache = BuilderIndexCache()

    private let titleLimit = 40
    private let noteLimit = 140
    /// Coach-published workouts are capped to keep the routine focused.
    private let coachMaxDrills = 8

    private var isPublishing: Bool { onPublish != nil }

    init(editing: CustomWorkout? = nil, onPublish: ((String, String, [String]) -> Void)? = nil) {
        self.editing = editing
        self.onPublish = onPublish
        _title = State(initialValue: editing?.title ?? "")
        _note = State(initialValue: "")
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
        guard items.count >= 2, !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if isPublishing { return items.count <= coachMaxDrills }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                DS.Colors.Bg.base.ignoresSafeArea()

                List {
                    nameSection
                    if isPublishing { noteSection }
                    drillsSection
                    Section { Color.clear.frame(height: 80).listRowBackground(Color.clear) }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))

                bottomBar
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isPublishing ? "Publish" : "Save") { save() }
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

    private var navTitle: String {
        if isPublishing { return "Publish Workout" }
        return editing == nil ? "New Workout" : "Edit Workout"
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            TextField(isPublishing ? "e.g. First Touch Friday" : "Name your workout", text: $title)
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

    private var noteSection: some View {
        Section {
            TextField("e.g. 30 minutes, focus on your weak foot", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 15))
                .foregroundStyle(DS.Colors.Ink.primary)
                .onChange(of: note) { _, newValue in
                    if newValue.count > noteLimit {
                        note = String(newValue.prefix(noteLimit))
                    }
                }
                .listRowBackground(DS.Colors.Bg.card)
        } header: {
            Text("Note to players (optional)")
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
                Text("Add at least 2 drills to \(isPublishing ? "publish" : "save").")
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            } else if isPublishing && items.count > coachMaxDrills {
                Text("Keep it to \(coachMaxDrills) drills or fewer.")
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

        if let onPublish {
            onPublish(trimmed, note.trimmingCharacters(in: .whitespacesAndNewlines), drillIDs)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
            return
        }

        let saved: CustomWorkout
        if let editing {
            editing.title = trimmed
            editing.drillIDs = drillIDs
            editing.updatedAt = Date()
            saved = editing
        } else {
            let workout = CustomWorkout(title: trimmed, drillIDs: drillIDs)
            context.insert(workout)
            saved = workout
        }
        try? context.save()
        SyncEngine.shared.enqueueCustomWorkout(saved)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Drill picker navigation routes

/// Pushes the drill list for one category inside the picker.
private struct PickerCategoryRoute: Hashable {
    let category: Category
    let discipline: Discipline
}

/// Pushes a read-only preview of a single drill inside the picker.
private struct PickerDrillRoute: Hashable {
    let drill: Drill
    let category: Category
    let discipline: Discipline
}

// MARK: - Drill picker

/// A browse-by-category picker that adds drills to the workout being built.
/// The root shows a hero card per category; tapping one drills into that
/// category's drill list, and each drill opens a read-only preview. Search
/// still flattens the whole curriculum into a quick result list.
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
                            searchResults
                        } else {
                            categoryBrowse
                        }
                    }
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)

                if addedCount > 0 { addedBar }
            }
            .navigationTitle("Add drills")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search all drills...")
            .navigationDestination(for: PickerCategoryRoute.self) { route in
                PickerCategoryView(
                    category: route.category,
                    discipline: route.discipline,
                    onAdd: addDrill
                )
            }
            .navigationDestination(for: PickerDrillRoute.self) { route in
                PickerDrillPreviewView(
                    drill: route.drill,
                    category: route.category,
                    discipline: route.discipline,
                    onAdd: addDrill
                )
            }
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

    private func addDrill(_ id: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onAdd(id)
        addedCount += 1
    }

    private var hasQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: Root — category hero cards

    private var categoryBrowse: some View {
        ForEach(disciplines) { discipline in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DS.Spacing.s8) {
                    DisciplineMark(kind: discipline.mark, size: 16)
                    Text(discipline.name)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, DS.Spacing.s12)

                ForEach(discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex })) { category in
                    let count = drillCount(in: category)
                    if count > 0 {
                        NavigationLink(value: PickerCategoryRoute(category: category, discipline: discipline)) {
                            CategoryHeroCard(category: category, discipline: discipline, drillCount: count)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.horizontal, DS.Spacing.s20)
                        .padding(.bottom, DS.Spacing.s12)
                    }
                }
            }
        }
    }

    private func drillCount(in category: Category) -> Int {
        category.levels.reduce(0) { $0 + $1.drills.count }
    }

    // MARK: Search results

    @ViewBuilder
    private var searchResults: some View {
        let results = viewModel.searchDrills()
        if results.isEmpty {
            emptyState
        } else {
            ForEach(results) { result in
                NavigationLink(value: PickerDrillRoute(
                    drill: result.drill,
                    category: result.category,
                    discipline: result.discipline
                )) {
                    PickerDrillRow(
                        drill: result.drill,
                        breadcrumb: "\(result.discipline.name) · \(result.category.name)",
                        isLast: result.id == results.last?.id
                    ) { addDrill(result.drill.id) }
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
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

// MARK: - Category hero card

/// A large, tappable card representing one category in the picker root.
private struct CategoryHeroCard: View {
    let category: Category
    let discipline: Discipline
    let drillCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.s16) {
            Text(category.letter)
                .font(DS.Typography.num(size: 24))
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(width: 48, height: 48)
                .background(DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Text(category.name)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(category.focus)
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(drillCount) \(drillCount == 1 ? "drill" : "drills")")
                    .style(.microSm)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .padding(.top, DS.Spacing.s4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .padding(.top, DS.Spacing.s16)
        }
        .padding(DS.Spacing.s16)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Category drill list (pushed)

/// Lists every drill inside one category. Each row opens a preview; the trailing
/// button adds the drill to the workout directly.
private struct PickerCategoryView: View {
    let category: Category
    let discipline: Discipline
    let onAdd: (String) -> Void

    private var drills: [Drill] {
        category.levels
            .sorted(by: { $0.sortIndex < $1.sortIndex })
            .flatMap { $0.drills.sorted(by: { $0.sortIndex < $1.sortIndex }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ForEach(drills) { drill in
                    NavigationLink(value: PickerDrillRoute(
                        drill: drill,
                        category: category,
                        discipline: discipline
                    )) {
                        PickerDrillRow(
                            drill: drill,
                            breadcrumb: "Level \(levelNumber(for: drill)) · \(drill.durationSec / 60) min",
                            isLast: drill.id == drills.last?.id
                        ) { onAdd(drill.id) }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.bottom, 100)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func levelNumber(for drill: Drill) -> Int {
        category.levels.first { lvl in lvl.drills.contains { $0.id == drill.id } }?.number ?? 1
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            HStack(spacing: DS.Spacing.s8) {
                DisciplineMark(kind: discipline.mark, size: 14)
                Text("\(discipline.name) · \(category.letter)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            Text(category.focus)
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
        .padding(.bottom, DS.Spacing.s8)
    }
}

// MARK: - Picker drill row

/// A single drill row used in both the category list and search results.
private struct PickerDrillRow: View {
    let drill: Drill
    let breadcrumb: String
    let isLast: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(drill.title)
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(breadcrumb)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s12 + 2)

            if !isLast {
                Hairline()
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .contentShape(Rectangle())
    }
}

// MARK: - Drill preview (pushed, read-only)

/// A read-only summary of what a drill consists of, with an "Add to workout"
/// button — no timer or session start, since this is the builder context.
private struct PickerDrillPreviewView: View {
    let drill: Drill
    let category: Category
    let discipline: Discipline
    let onAdd: (String) -> Void

    @State private var didAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                if let setup = drill.setupSummary {
                    section("SET-UP") {
                        Text(setup)
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                section("PURPOSE") {
                    Text(drill.how)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let listItems = drill.isMentalExercise ? drill.steps : drill.instructions
                if !listItems.isEmpty {
                    section(drill.isMentalExercise ? "THE EXERCISE" : "HOW TO DO IT") {
                        numberedList(listItems)
                    }
                }
                if !drill.coachingPoints.isEmpty {
                    section("COACHING POINTS") {
                        numberedList(drill.coachingPoints)
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle(drill.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            addButton
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            HStack(spacing: DS.Spacing.s8) {
                DisciplineMark(kind: discipline.mark, size: 14)
                Text("\(discipline.name) · \(category.name)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            Text(drill.title)
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(drill.focus) · \(drill.durationSec / 60) min")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func numberedList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: DS.Spacing.s12) {
                    Text("\(index + 1)")
                        .style(.foot)
                        .fontWeight(.bold)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(width: 24, height: 24)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Circle())
                    Text(item)
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onAdd(drill.id)
            withAnimation(DS.Motion.standardSpring) { didAdd = true }
        } label: {
            HStack(spacing: DS.Spacing.s8) {
                Image(systemName: didAdd ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text(didAdd ? "Added to workout" : "Add to workout")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(DS.Colors.Ground.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.vertical, DS.Spacing.s12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Hairline() }
    }
}
