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

    private var viewModel: CurriculumSearchViewModel {
        CurriculumSearchViewModel(disciplines: disciplines, searchText: searchText)
    }

    var body: some View {
        let results = viewModel.searchDrills()

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                addNewRow
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s16)
                    .padding(.bottom, DS.Spacing.s8)

                Eyebrow(text: "\(results.count) Drills")
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.vertical, DS.Spacing.s8)

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
        .searchable(text: $searchText, prompt: "Search drills to edit…")
        .sheet(item: $editing) { drill in
            CoachDrillEditSheet(drill: drill, model: model)
        }
        .sheet(isPresented: $showNew) {
            CoachNewDrillSheet(disciplines: disciplines, model: model)
        }
    }

    private var addNewRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showNew = true
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
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
        }
        .preferredColorScheme(.dark)
    }

    private func save() async {
        isSaving = true
        await model.publishDrillEdit(original: drill, edited: fields)
        await CurriculumOverlay.refresh(context: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func hide() async {
        await model.hideDrill(drill)
        await CurriculumOverlay.refresh(context: modelContext)
        dismiss()
    }

    private func revert() async {
        await model.revertDrillEdit(drillID: drill.id)
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
        }
        .preferredColorScheme(.dark)
    }

    private func publish() async {
        isSaving = true
        await model.publishNewDrill(drillID: String(newDrillID), categoryID: categoryID, levelNumber: levelNumber, fields: fields)
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
                Text("Upload failed").style(.foot).foregroundStyle(Color(hex: "#FF453A"))
                Button("Retry", action: onRetry)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Gold.textLight)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            default:
                Text(label).style(.foot).foregroundStyle(DS.Colors.Ink.primary)
                if hasMedia || state == .done {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.Gold.base)
                }
            }
            Spacer()
            if hasMedia {
                Button("Remove", action: onRemove)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
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
