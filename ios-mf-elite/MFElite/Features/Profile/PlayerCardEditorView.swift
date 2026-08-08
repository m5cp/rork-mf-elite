//
//  PlayerCardEditorView.swift
//  MFElite
//
//  Instagram-style editor for the player card: swap the background photo, drop
//  draggable / pinchable / rotatable text stickers, recolor, free-hand draw, and
//  then share or save the result. Edits apply to a local working copy and only
//  persist to PlayerCardStore on Save.
//

import SwiftUI
import PhotosUI

struct PlayerCardEditorView: View {
    let player: CardPlayerInfo

    init(player: CardPlayerInfo) {
        self.player = player
    }

    @Environment(\.dismiss) private var dismiss
    private var cardStore = PlayerCardStore.shared
    private var profile = PlayerProfileStore.shared

    // Working copy — committed on Save.
    @State private var design: CardDesign = PlayerCardStore.shared.design
    /// The portrait shown in the card photo box — mirrors the profile avatar so
    /// the card and profile always match.
    private var photo: UIImage? { profile.avatarPhoto }

    // Tool / panel state
    enum Panel: Equatable { case none, theme, draw }
    @State private var panel: Panel = .none
    @State private var selectedID: UUID?

    // Photo
    @State private var photoItem: PhotosPickerItem?

    // Text editing
    @State private var editingID: UUID?
    @State private var editingText: String = ""

    // Drawing
    @State private var penColorHex: String = "FF453A"
    @State private var penWidth: Double = 0.012
    @State private var currentPoints: [NormalizedPoint] = []

    // Gesture bases
    @State private var dragID: UUID?
    @State private var dragBase: CGPoint = .zero
    @State private var scaleBase: Double?
    @State private var rotationBase: Double?

    @State private var shareImage: ShareableImage?

    /// The avatar as it was when this editor opened.
    ///
    /// Picking a photo and hitting "Remove photo" both write straight through
    /// to the shared profile store — the remove even deletes the file — so
    /// Cancel used to leave the change in place everywhere in the app. Captured
    /// on appear, put back on Cancel.
    @State private var avatarBackup: AvatarSnapshot?
    /// Set by Cancel so a photo still being decoded can't land afterwards.
    @State private var isCancelled = false

    private var isDrawing: Bool { panel == .draw }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvasArea
                controlPanel
                toolbar
            }
            .background(DS.Colors.Bg.base)
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: Binding(
                get: { editingID != nil },
                set: { if !$0 { editingID = nil } }
            )) {
                textEditorSheet
            }
            .sheet(item: $shareImage) { item in
                ShareSheet(items: [item.image])
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                if avatarBackup == nil { avatarBackup = profile.avatarSnapshot() }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    // Not `.task(id:)` — this Task outlives the view, so a
                    // decode still in flight when Cancel is tapped would
                    // re-apply the photo the user just discarded.
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data), !isCancelled {
                        profile.setPhotoAvatar(image)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
            }
        }
    }

    // MARK: - Canvas

    private var canvasArea: some View {
        GeometryReader { geo in
            let available = geo.size
            let w = min(available.width - DS.Spacing.s32, (available.height - DS.Spacing.s24) / cardAspect)
            let cardW = max(w, 0)
            let cardH = cardW * cardAspect

            ZStack {
                PlayerCardCanvas(
                    design: design,
                    photo: photo,
                    player: player,
                    width: cardW,
                    includeOverlays: false
                )

                // Interactive text stickers
                ForEach(design.overlays) { overlay in
                    stickerView(overlay, cardW: cardW, cardH: cardH)
                }

                // In-progress drawing
                if isDrawing {
                    drawingOverlay(cardW: cardW, cardH: cardH)
                }
            }
            .frame(width: cardW, height: cardH)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isDrawing {
                    selectedID = nil
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stickerView(overlay: CardTextOverlay, cardW: CGFloat, cardH: CGFloat) -> some View {
        let isSelected = selectedID == overlay.id
        return CardTextLabel(overlay: overlay, cardWidth: cardW)
            .padding(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(isSelected ? 0.9 : 0), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .position(x: overlay.x * cardW, y: overlay.y * cardH)
            .allowsHitTesting(!isDrawing)
            .onTapGesture(count: 2) {
                beginEditing(overlay)
            }
            .onTapGesture {
                selectedID = overlay.id
                panel = .none
            }
            .gesture(dragGesture(overlay, cardW: cardW, cardH: cardH))
            .simultaneousGesture(magnifyGesture(overlay))
            .simultaneousGesture(rotateGesture(overlay))
    }

    // overloaded label for cleaner call site
    private func stickerView(_ overlay: CardTextOverlay, cardW: CGFloat, cardH: CGFloat) -> some View {
        stickerView(overlay: overlay, cardW: cardW, cardH: cardH)
    }

    private func drawingOverlay(cardW: CGFloat, cardH: CGFloat) -> some View {
        Canvas { context, size in
            guard currentPoints.count > 1 else { return }
            var path = Path()
            path.move(to: CGPoint(x: currentPoints[0].x * size.width, y: currentPoints[0].y * size.height))
            for p in currentPoints.dropFirst() {
                path.addLine(to: CGPoint(x: p.x * size.width, y: p.y * size.height))
            }
            context.stroke(
                path,
                with: .color(Color(hex: penColorHex)),
                style: StrokeStyle(lineWidth: penWidth * size.width, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: cardW, height: cardH)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let nx = min(max(value.location.x / cardW, 0), 1)
                    let ny = min(max(value.location.y / cardH, 0), 1)
                    currentPoints.append(NormalizedPoint(x: Double(nx), y: Double(ny)))
                }
                .onEnded { _ in
                    if currentPoints.count > 1 {
                        design.strokes.append(
                            CardStroke(points: currentPoints, colorHex: penColorHex, widthFraction: penWidth)
                        )
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    currentPoints = []
                }
        )
    }

    // MARK: - Gestures

    private func dragGesture(_ overlay: CardTextOverlay, cardW: CGFloat, cardH: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragID != overlay.id {
                    dragID = overlay.id
                    dragBase = CGPoint(x: overlay.x, y: overlay.y)
                    selectedID = overlay.id
                }
                let nx = dragBase.x + value.translation.width / cardW
                let ny = dragBase.y + value.translation.height / cardH
                update(overlay.id) {
                    $0.x = min(max(Double(nx), 0), 1)
                    $0.y = min(max(Double(ny), 0), 1)
                }
            }
            .onEnded { _ in dragID = nil }
    }

    private func magnifyGesture(_ overlay: CardTextOverlay) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if scaleBase == nil { scaleBase = overlay.sizeFraction }
                let base = scaleBase ?? overlay.sizeFraction
                update(overlay.id) {
                    $0.sizeFraction = min(max(base * value.magnification, 0.03), 0.45)
                }
            }
            .onEnded { _ in scaleBase = nil }
    }

    private func rotateGesture(_ overlay: CardTextOverlay) -> some Gesture {
        RotateGesture()
            .onChanged { value in
                if rotationBase == nil { rotationBase = overlay.rotation }
                let base = rotationBase ?? overlay.rotation
                update(overlay.id) { $0.rotation = base + value.rotation.radians }
            }
            .onEnded { _ in rotationBase = nil }
    }

    // MARK: - Control panel (contextual)

    @ViewBuilder
    private var controlPanel: some View {
        if let id = selectedID, let overlay = design.overlays.first(where: { $0.id == id }) {
            selectedOverlayPanel(overlay)
        } else if panel == .theme {
            themePanel
        } else if panel == .draw {
            drawPanel
        }
    }

    private func selectedOverlayPanel(_ overlay: CardTextOverlay) -> some View {
        VStack(spacing: DS.Spacing.s12) {
            colorStrip(selectedHex: overlay.colorHex) { hex in
                update(overlay.id) { $0.colorHex = hex }
            }
            HStack(spacing: DS.Spacing.s12) {
                panelChip(icon: "pencil", label: "Edit") { beginEditing(overlay) }
                panelChip(icon: overlay.isBold ? "bold" : "textformat", label: overlay.isBold ? "Bold" : "Regular") {
                    update(overlay.id) { $0.isBold.toggle() }
                }
                panelChip(icon: "trash", label: "Delete", tint: Color(hex: "FF453A")) {
                    design.overlays.removeAll { $0.id == overlay.id }
                    selectedID = nil
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
            }
        }
        .padding(DS.Spacing.s16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var themePanel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: "Theme")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.s12) {
                    ForEach(CardTheme.allCases) { theme in
                        themeSwatch(theme)
                    }
                }
            }
            HStack(spacing: DS.Spacing.s12) {
                panelChip(
                    icon: design.showStatPlate ? "checkmark.rectangle" : "rectangle",
                    label: "Show stats"
                ) {
                    design.showStatPlate.toggle()
                }
                if profile.avatar == .photo {
                    panelChip(icon: "photo.badge.minus", label: "Remove photo", tint: Color(hex: "FF453A")) {
                        profile.clearAvatar()
                    }
                }
            }
        }
        .padding(DS.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var drawPanel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack {
                Eyebrow(text: "Draw")
                Spacer()
                Button {
                    if !design.strokes.isEmpty {
                        design.strokes.removeLast()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .style(.foot)
                        .foregroundStyle(design.strokes.isEmpty ? DS.Colors.Ink.disabled : DS.Colors.Ink.primary)
                }
                .disabled(design.strokes.isEmpty)
            }
            colorStrip(selectedHex: penColorHex) { hex in penColorHex = hex }
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: "scribble")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                Slider(value: $penWidth, in: 0.004...0.03)
                    .tint(.white)
            }
        }
        .padding(DS.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func colorStrip(selectedHex: String, onPick: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s12) {
                ForEach(CardPalette.hexes, id: \.self) { hex in
                    Button {
                        onPick(hex)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: hex == "000000" ? 1 : 0))
                            .overlay(
                                Circle().stroke(.white, lineWidth: selectedHex == hex ? 3 : 0)
                                    .padding(-3)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func themeSwatch(_ theme: CardTheme) -> some View {
        let isSelected = design.theme == theme && !design.hasPhoto
        return Button {
            design.theme = theme
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(LinearGradient(colors: theme.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 60)
                    .overlay(alignment: .bottom) {
                        Circle().fill(theme.accent).frame(width: 10, height: 10).padding(.bottom, 6)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .stroke(.white, lineWidth: isSelected ? 2 : 0)
                    )
                Text(theme.name)
                    .style(.microSm)
                    .foregroundStyle(isSelected ? DS.Colors.Ink.primary : DS.Colors.Ink.quaternary)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func panelChip(icon: String, label: String, tint: Color = DS.Colors.Ink.primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .style(.microSm)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.s12)
            .background(DS.Colors.Bg.raised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Bottom toolbar

    private var toolbar: some View {
        HStack(spacing: 0) {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                toolLabel(icon: "photo", label: "Photo", active: false)
            }
            toolButton(icon: "textformat", label: "Text", active: false) {
                addText()
            }
            toolButton(icon: "paintpalette", label: "Theme", active: panel == .theme) {
                selectedID = nil
                panel = panel == .theme ? .none : .theme
            }
            toolButton(icon: "scribble.variable", label: "Draw", active: panel == .draw) {
                selectedID = nil
                panel = panel == .draw ? .none : .draw
            }
            toolButton(icon: "square.and.arrow.up", label: "Share", active: false) {
                shareCurrent()
            }
        }
        .padding(.horizontal, DS.Spacing.s12)
        .padding(.top, DS.Spacing.s12)
        .padding(.bottom, DS.Spacing.s8)
        .background(DS.Colors.Bg.elevated)
        .overlay(alignment: .top) { Hairline() }
    }

    private func toolButton(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) { action() }
        } label: {
            toolLabel(icon: icon, label: label, active: active)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func toolLabel(icon: String, label: String, active: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
            Text(label)
                .style(.microSm)
        }
        .foregroundStyle(active ? DS.Colors.Ink.primary : DS.Colors.Ink.tertiary)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    // MARK: - Text editor sheet

    private var textEditorSheet: some View {
        NavigationStack {
            VStack {
                TextField("Type something", text: $editingText, axis: .vertical)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .tint(.white)
                    .padding(DS.Spacing.s16)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .padding(DS.Spacing.s20)
                Spacer()
            }
            .background(DS.Colors.Bg.base)
            .navigationTitle("Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { cancelEditing() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { commitEditing() }
                        .fontWeight(.semibold)
                        .disabled(editingText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(220)])
    }

    // MARK: - Actions

    private func addText() {
        let overlay = CardTextOverlay(text: "", y: 0.4)
        design.overlays.append(overlay)
        editingText = ""
        editingID = overlay.id
        selectedID = overlay.id
        panel = .none
    }

    private func beginEditing(_ overlay: CardTextOverlay) {
        editingText = overlay.text
        editingID = overlay.id
        selectedID = overlay.id
    }

    private func commitEditing() {
        guard let id = editingID else { return }
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            design.overlays.removeAll { $0.id == id }
            selectedID = nil
        } else {
            update(id) { $0.text = trimmed }
        }
        editingID = nil
    }

    private func cancelEditing() {
        // Remove a never-filled new sticker.
        if let id = editingID,
           let overlay = design.overlays.first(where: { $0.id == id }),
           overlay.text.isEmpty {
            design.overlays.removeAll { $0.id == id }
            selectedID = nil
        }
        editingID = nil
    }

    private func update(_ id: UUID, _ mutate: (inout CardTextOverlay) -> Void) {
        guard let idx = design.overlays.firstIndex(where: { $0.id == id }) else { return }
        mutate(&design.overlays[idx])
    }

    private func save() {
        cardStore.save(design)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    /// Discard everything this editor changed — including the avatar, which is
    /// written through to the shared profile store as soon as it's picked.
    private func cancel() {
        isCancelled = true
        if let avatarBackup { profile.restoreAvatar(avatarBackup) }
        dismiss()
    }

    private func shareCurrent() {
        selectedID = nil
        if let image = CardExporter.render(design: design, photo: photo, player: player) {
            shareImage = ShareableImage(image: image)
        }
    }
}
