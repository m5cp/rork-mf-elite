//
//  CoachDrillEditorView.swift
//  MFElite
//
//  Coach Mode "DRILL EDITOR": a searchable list of every curriculum drill plus an
//  "Add a new drill" action. Editing publishes a `curriculum_edits` overlay row —
//  it changes drill CONTENT only and never touches any player's progress, history,
//  streaks, favorites, routines, or custom workouts.
//

import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

/// Pushes the coach drill-editor list inside the Coach tab.
struct CoachDrillEditorRoute: Hashable {}

struct CoachDrillEditorView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Environment(\.modelContext) private var modelContext
    let model: CoachViewModel

    @State private var searchText = ""
    @State private var editing: Drill?
    @State private var showNew = false
    @State private var sortOrder: DrillSortOrder = .curriculum
    @State private var filterDisciplineID: String?
    @State private var filterLevel: Int?
    @State private var editedOnly = false

    /// How the editor list is ordered. Curriculum order is the default because
    /// it matches how the drills are laid out everywhere else in the app.
    enum DrillSortOrder: String, CaseIterable, Identifiable {
        case curriculum = "Curriculum order"
        case titleAZ = "Title A–Z"
        case titleZA = "Title Z–A"
        case levelAscending = "Level (low to high)"
        case levelDescending = "Level (high to low)"
        case shortestFirst = "Shortest first"
        case longestFirst = "Longest first"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .curriculum:                     return "list.number"
            case .titleAZ, .titleZA:              return "textformat"
            case .levelAscending, .levelDescending: return "chart.bar"
            case .shortestFirst, .longestFirst:   return "clock"
            }
        }
    }

    private var viewModel: CurriculumSearchViewModel {
        CurriculumSearchViewModel(disciplines: disciplines, searchText: searchText)
    }

    /// Every level number present in the curriculum, for the level filter.
    private var allLevelNumbers: [Int] {
        var levels: Set<Int> = []
        for discipline in disciplines {
            for category in discipline.categories {
                for level in category.levels { levels.insert(level.number) }
            }
        }
        return levels.sorted()
    }

    /// Search results with the coach's filters and sort applied. Without this
    /// the editor was an unordered 270-row wall with no way to narrow it.
    private var filteredResults: [SearchResult] {
        var results = viewModel.searchDrills()

        if let filterDisciplineID {
            results = results.filter { $0.discipline.id == filterDisciplineID }
        }
        if let filterLevel {
            results = results.filter { $0.level.number == filterLevel }
        }
        if editedOnly {
            results = results.filter { $0.drill.coachEditedBy != nil || $0.drill.isCoachHidden }
        }

        switch sortOrder {
        case .curriculum:
            results.sort { $0.order < $1.order }
        case .titleAZ:
            results.sort { $0.drill.title.localizedCaseInsensitiveCompare($1.drill.title) == .orderedAscending }
        case .titleZA:
            results.sort { $0.drill.title.localizedCaseInsensitiveCompare($1.drill.title) == .orderedDescending }
        case .levelAscending:
            results.sort { ($0.level.number, $0.order) < ($1.level.number, $1.order) }
        case .levelDescending:
            results.sort { ($0.level.number, -$0.order) > ($1.level.number, -$1.order) }
        case .shortestFirst:
            results.sort { ($0.drill.durationSec, $0.order) < ($1.drill.durationSec, $1.order) }
        case .longestFirst:
            results.sort { ($0.drill.durationSec, -$0.order) > ($1.drill.durationSec, -$1.order) }
        }
        return results
    }

    private var hasActiveFilter: Bool {
        filterDisciplineID != nil || filterLevel != nil || editedOnly
    }

    var body: some View {
        let results = filteredResults

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                addNewRow
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s16)
                    .padding(.bottom, DS.Spacing.s8)

                filterBar

                HStack {
                    Eyebrow(text: "\(results.count) Drill\(results.count == 1 ? "" : "s")")
                    Spacer(minLength: DS.Spacing.s8)
                    sortMenu
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.vertical, DS.Spacing.s8)

                if results.isEmpty {
                    Text("No drills match. Try clearing the filters or the search.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, DS.Spacing.s20)
                        .padding(.top, DS.Spacing.s48)
                }

                ForEach(results) { result in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        editing = result.drill
                    } label: {
                        EditorDrillRow(
                            drill: result.drill,
                            breadcrumb: "\(result.discipline.name) · \(result.category.name) · LV\(result.level.number)",
                            isLast: result.id == results.last?.id
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Drill Editor")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search 270 drills by name, focus or category")
        .sheet(item: $editing) { drill in
            CoachDrillEditSheet(drill: drill, model: model)
        }
        .sheet(isPresented: $showNew) {
            CoachNewDrillSheet(disciplines: disciplines, model: model)
        }
    }

    /// Sort picker. Kept as a Menu so it costs one row of chrome rather than a
    /// second scrolling bar.
    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sortOrder) {
                ForEach(DrillSortOrder.allCases) { order in
                    Label(order.rawValue, systemImage: order.icon).tag(order)
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.s4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 11, weight: .bold))
                Text(sortOrder.rawValue)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(DS.Colors.Ink.secondary)
        }
    }

    /// Discipline / level / edited filters plus a clear-all.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s8) {
                if hasActiveFilter {
                    chip(label: "Clear", selected: false, systemImage: "xmark") {
                        filterDisciplineID = nil
                        filterLevel = nil
                        editedOnly = false
                    }
                }

                chip(label: "Edited", selected: editedOnly, systemImage: "pencil") {
                    editedOnly.toggle()
                }

                ForEach(disciplines) { discipline in
                    chip(
                        label: discipline.name,
                        selected: filterDisciplineID == discipline.id
                    ) {
                        filterDisciplineID = (filterDisciplineID == discipline.id) ? nil : discipline.id
                    }
                }

                ForEach(allLevelNumbers, id: \.self) { level in
                    chip(label: "LV\(level)", selected: filterLevel == level) {
                        filterLevel = (filterLevel == level) ? nil : level
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .padding(.bottom, DS.Spacing.s4)
    }

    private func chip(
        label: String,
        selected: Bool,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) { action() }
        } label: {
            HStack(spacing: DS.Spacing.s4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(selected ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary)
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(selected ? Color.white : DS.Colors.Bg.raised)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var addNewRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showNew = true
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                SectionIcon(systemName: "plus.circle.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a new drill")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Author a drill and place it in a category & level")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(DS.Spacing.s16)
            .frame(maxWidth: .infinity)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Editor drill row

private struct EditorDrillRow: View {
    let drill: Drill
    let breadcrumb: String
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.s8) {
                        Text(drill.title)
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .lineLimit(1)
                        if drill.isCoachHidden { tag("HIDDEN") }
                        else if drill.coachEditedBy != nil { tag("EDITED") }
                    }
                    Text(breadcrumb.uppercased())
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s12 + 2)
            .padding(.horizontal, DS.Spacing.s20)
            .contentShape(Rectangle())

            if !isLast { Hairline().padding(.horizontal, DS.Spacing.s20) }
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(DS.Colors.Ink.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DS.Colors.Bg.raised)
            .clipShape(Capsule())
    }
}

// MARK: - Edit existing drill

private struct CoachDrillEditSheet: View {
    let drill: Drill
    let model: CoachViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var fields: DrillEditFields
    @State private var isSaving = false
    @State private var showHideConfirm = false
    /// Non-nil when the last write failed, so the sheet stays open and says so
    /// instead of closing with a success buzz.
    @State private var saveError: String?

    init(drill: Drill, model: CoachViewModel) {
        self.drill = drill
        self.model = model
        _fields = State(initialValue: DrillEditFields(drill: drill))
    }

    var body: some View {
        NavigationStack {
            DrillFieldForm(fields: $fields) {
                Section {
                    CoachDrillMediaSection(drillID: drill.id, videoURL: $fields.videoURL, imageURL: $fields.imageURL)
                        .listRowBackground(DS.Colors.Bg.card)
                } header: {
                    Text("Media").foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Section {
                    Button(role: .destructive) { showHideConfirm = true } label: {
                        Label("Hide this drill", systemImage: "eye.slash")
                    }
                    .listRowBackground(DS.Colors.Bg.card)
                    if drill.coachEditedBy != nil || drill.isCoachHidden {
                        Button { Task { await revert() } } label: {
                            Label("Revert to original", systemImage: "arrow.uturn.backward")
                                .foregroundStyle(DS.Colors.Ink.secondary)
                        }
                        .listRowBackground(DS.Colors.Bg.card)
                    }
                } footer: {
                    Text("Edits change drill content for everyone. Players keep all their progress, history and mastery.")
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
            }
            .navigationTitle("Edit Drill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .fontWeight(.bold)
                        .foregroundStyle(fields.title.trimmingCharacters(in: .whitespaces).isEmpty ? DS.Colors.Ink.quaternary : DS.Colors.Ink.primary)
                        .disabled(isSaving || fields.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Hide this drill?", isPresented: $showHideConfirm, titleVisibility: .visible) {
                Button("Hide drill", role: .destructive) { Task { await hide() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Players who haven't trained it stop seeing it. Anyone who already logged it keeps their history.")
            }
            .alert("Couldn't save", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Save, and only dismiss when the write actually landed. This used to fire
    /// a success haptic and close regardless: a coach authoring a drill on a
    /// flaky connection got a confirmation buzz and lost the whole thing.
    private func save() async {
        isSaving = true
        let ok = await model.publishDrillEdit(original: drill, edited: fields)
        isSaving = false
        guard ok else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            saveError = "Couldn't save. Check your connection and try again."
            return
        }
        saveError = nil
        await CurriculumOverlay.refresh(context: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func hide() async {
        guard await model.hideDrill(drill) else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            saveError = "Couldn't hide this drill. Check your connection and try again."
            return
        }
        await CurriculumOverlay.refresh(context: modelContext)
        dismiss()
    }

    private func revert() async {
        guard await model.revertDrillEdit(drillID: drill.id) else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            saveError = "Couldn't revert this drill. Check your connection and try again."
            return
        }
        await CurriculumOverlay.refresh(context: modelContext)
        dismiss()
    }
}

// MARK: - New drill

private struct CoachNewDrillSheet: View {
    let disciplines: [Discipline]
    let model: CoachViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var fields = DrillEditFields()
    @State private var categoryID: String = ""
    @State private var levelNumber: Int = 1
    @State private var isSaving = false
    /// Non-nil when publishing failed, so the sheet stays open and says so.
    @State private var saveError: String?
    /// Stable id generated once when the sheet appears, so media uploads and the
    /// published drill share the same identifier.
    @State private var newDrillID = "COACH-" + UUID().uuidString.prefix(8).uppercased()

    private var allCategories: [(discipline: Discipline, category: Category)] {
        disciplines.flatMap { disc in
            disc.categories.sorted(by: { $0.sortIndex < $1.sortIndex }).map { (disc, $0) }
        }
    }

    private var selectedCategory: Category? {
        allCategories.first { $0.category.id == categoryID }?.category
    }

    private var levelNumbers: [Int] {
        (selectedCategory?.levels.map(\.number).sorted()) ?? [1]
    }

    private var canSave: Bool {
        !fields.title.trimmingCharacters(in: .whitespaces).isEmpty && !categoryID.isEmpty
    }

    var body: some View {
        NavigationStack {
            DrillFieldForm(fields: $fields) {
                Section {
                    Picker("Category", selection: $categoryID) {
                        Text("Choose a category").tag("")
                        ForEach(allCategories, id: \.category.id) { item in
                            Text("\(item.discipline.name) · \(item.category.name)").tag(item.category.id)
                        }
                    }
                    .listRowBackground(DS.Colors.Bg.card)
                    Picker("Level", selection: $levelNumber) {
                        ForEach(levelNumbers, id: \.self) { Text("Level \($0)").tag($0) }
                    }
                    .listRowBackground(DS.Colors.Bg.card)
                } header: {
                    Text("Placement").foregroundStyle(DS.Colors.Ink.tertiary)
                }
                Section {
                    CoachDrillMediaSection(drillID: String(newDrillID), videoURL: $fields.videoURL, imageURL: $fields.imageURL)
                        .listRowBackground(DS.Colors.Bg.card)
                } header: {
                    Text("Media").foregroundStyle(DS.Colors.Ink.tertiary)
                }
            }
            .navigationTitle("New Drill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") { Task { await publish() } }
                        .fontWeight(.bold)
                        .foregroundStyle(canSave ? DS.Colors.Ink.primary : DS.Colors.Ink.quaternary)
                        .disabled(isSaving || !canSave)
                }
            }
            .onChange(of: categoryID) { _, _ in
                if !levelNumbers.contains(levelNumber) { levelNumber = levelNumbers.first ?? 1 }
            }
            .alert("Couldn't publish", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func publish() async {
        isSaving = true
        let ok = await model.publishNewDrill(
            drillID: String(newDrillID), categoryID: categoryID,
            levelNumber: levelNumber, fields: fields
        )
        isSaving = false
        guard ok else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            saveError = "Couldn't publish this drill. Check your connection and try again."
            return
        }
        saveError = nil
        await CurriculumOverlay.refresh(context: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Shared drill field form

/// The editable content form shared by the edit + new-drill sheets. `extra` lets
/// each caller append its own sections (placement, hide/revert actions).
private struct DrillFieldForm<Extra: View>: View {
    @Binding var fields: DrillEditFields
    @ViewBuilder let extra: () -> Extra

    var body: some View {
        List {
            Section {
                textField("Title", text: $fields.title)
                textField("Focus", text: $fields.focus)
                TextField("How / purpose", text: $fields.how, axis: .vertical)
                    .lineLimit(2...5)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .listRowBackground(DS.Colors.Bg.card)
            } header: {
                Text("Overview").foregroundStyle(DS.Colors.Ink.tertiary)
            }

            Section {
                Stepper("Duration: \(fields.durationSec / 60)m \(fields.durationSec % 60)s",
                        value: $fields.durationSec, in: 30...1800, step: 30)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .listRowBackground(DS.Colors.Bg.card)
                Stepper("Sets: \(fields.sets)", value: $fields.sets, in: 1...10)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .listRowBackground(DS.Colors.Bg.card)
            } header: {
                Text("Timing").foregroundStyle(DS.Colors.Ink.tertiary)
            }

            EditableLines(title: "Instructions", lines: $fields.instructions, placeholder: "Step")
            EditableLines(title: "Coaching points", lines: $fields.coachingPoints, placeholder: "Coaching point")
            EditableLines(title: "Equipment", lines: $fields.equipment, placeholder: "e.g. 4 cones")

            Section {
                textField("e.g. 5x5 yards", text: $fields.space)
            } header: {
                Text("Space (optional)").foregroundStyle(DS.Colors.Ink.tertiary)
            }

            extra()

            Section { Color.clear.frame(height: 40).listRowBackground(Color.clear) }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DS.Colors.Bg.base)
    }

    private func textField(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .foregroundStyle(DS.Colors.Ink.primary)
            .listRowBackground(DS.Colors.Bg.card)
    }
}

/// An editable list of text lines with add / delete, for instructions etc.
private struct EditableLines: View {
    let title: String
    @Binding var lines: [String]
    let placeholder: String

    var body: some View {
        Section {
            ForEach(lines.indices, id: \.self) { index in
                TextField("\(placeholder) \(index + 1)", text: Binding(
                    get: { index < lines.count ? lines[index] : "" },
                    set: { if index < lines.count { lines[index] = $0 } }
                ), axis: .vertical)
                    .lineLimit(1...4)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .listRowBackground(DS.Colors.Bg.card)
            }
            .onDelete { lines.remove(atOffsets: $0) }

            Button {
                lines.append("")
            } label: {
                Label("Add \(placeholder.lowercased())", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            .listRowBackground(DS.Colors.Bg.card)
        } header: {
            Text(title).foregroundStyle(DS.Colors.Ink.tertiary)
        }
    }
}

// MARK: - Shared coach media section (image + video upload)

/// Photo + video upload for a drill. Used by BOTH the edit sheet and the
/// new-drill sheet. Uploads to public Supabase buckets; only active coaches
/// pass the server-side storage policies (enforced in Phase 0 SQL).
struct CoachDrillMediaSection: View {
    let drillID: String
    @Binding var videoURL: String?
    @Binding var imageURL: String?

    @State private var pickedVideo: PhotosPickerItem?
    @State private var pickedImage: PhotosPickerItem?
    @State private var videoState: MediaUploadState = .idle
    @State private var imageState: MediaUploadState = .idle

    enum MediaUploadState: Equatable { case idle, uploading, done, failed }

    private var hasImage: Bool { !(imageURL ?? "").isEmpty }
    private var hasVideo: Bool { !(videoURL ?? "").isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            SectionHead(title: "Media")

            mediaRow(
                label: hasImage ? "Replace photo" : "Add reference photo",
                icon: "photo",
                state: imageState,
                hasMedia: hasImage,
                picker: PhotosPicker(selection: $pickedImage, matching: .images) {
                    EmptyView()
                },
                onRemove: { imageURL = nil; imageState = .idle },
                onRetry: { Task { await uploadImage() } }
            )

            mediaRow(
                label: hasVideo ? "Replace video" : "Add demo video",
                icon: "video",
                state: videoState,
                hasMedia: hasVideo,
                picker: PhotosPicker(selection: $pickedVideo, matching: .videos) {
                    EmptyView()
                },
                onRemove: { videoURL = nil; videoState = .idle },
                onRetry: { Task { await uploadVideo() } }
            )
        }
        .onChange(of: pickedImage) { _, _ in Task { await uploadImage() } }
        .onChange(of: pickedVideo) { _, _ in Task { await uploadVideo() } }
    }

    @ViewBuilder
    private func mediaRow<P: View>(
        label: String, icon: String, state: MediaUploadState, hasMedia: Bool,
        picker: P, onRemove: @escaping () -> Void, onRetry: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: icon)
                .foregroundStyle(DS.Colors.Gold.base)
            switch state {
            case .uploading:
                ProgressView().tint(DS.Colors.Gold.base)
                Text("Uploading\u{2026}").style(.foot).foregroundStyle(DS.Colors.Ink.secondary)
            case .failed:
                Text("Upload failed").style(.foot).foregroundStyle(DS.Colors.Status.bad)
                Button("Retry", action: onRetry)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Gold.textLight)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            default:
                Text(label).style(.foot).foregroundStyle(DS.Colors.Ink.primary)
            }
            Spacer()
            // Standard confirmation affordance: a checkmark that says "yes,
            // that one is attached", rather than the label quietly changing.
            if state != .uploading, state != .failed {
                ConfirmBadge(isConfirmed: hasMedia || state == .done, label: "Attached")
            }
            if hasMedia {
                Button("Remove", action: onRemove)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .frame(minHeight: 44)
            }
        }
        .padding(DS.Spacing.s12)
        .background(DS.Colors.Bg.raised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(picker.allowsHitTesting(false))
        .background(picker.opacity(0.011)) // full-row PhotosPicker hit target
    }

    private func uploadImage() async {
        guard let item = pickedImage else { return }
        imageState = .uploading
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpeg = image.mf_resized(maxDimension: 1600).jpegData(compressionQuality: 0.85),
              jpeg.count <= 10 * 1024 * 1024 else {
            imageState = .failed
            return
        }
        let path = "\(drillID).jpg"
        let ok = await SupabaseClient.shared.uploadStorage(
            bucket: "drill-images", path: path, data: jpeg, contentType: "image/jpeg"
        )
        if ok {
            imageURL = SupabaseClient.shared.publicStorageURL(bucket: "drill-images", path: path)
            imageState = .done
        } else {
            imageState = .failed
        }
    }

    private func uploadVideo() async {
        guard let item = pickedVideo else { return }
        videoState = .uploading
        guard let data = try? await item.loadTransferable(type: Data.self),
              data.count <= 100 * 1024 * 1024 else {
            videoState = .failed
            return
        }
        let path = "\(drillID).mp4"
        let ok = await SupabaseClient.shared.uploadStorage(
            bucket: "drill-videos", path: path, data: data, contentType: "video/mp4"
        )
        if ok {
            videoURL = SupabaseClient.shared.publicStorageURL(bucket: "drill-videos", path: path)
            videoState = .done
        } else {
            videoState = .failed
        }
    }
}
