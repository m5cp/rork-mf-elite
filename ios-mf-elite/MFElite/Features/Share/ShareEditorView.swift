//
//  ShareEditorView.swift
//  MFElite
//
//  The share editor: pick a format, theme and backdrop, toggle private details,
//  add a caption chip, and place / resize / delete stickers on the card before
//  sharing. The live preview always mirrors the exported image. The preview
//  area keeps a constant size — trays and transient UI overlay it, never resize
//  it.
//

import SwiftUI

struct ShareEditorView: View {
    @StateObject private var model: ShareEditorModel
    @Environment(\.dismiss) private var dismiss

    @State private var exported: ShareableImage?
    @State private var captionDraft = ""

    /// Gold used for the editor chrome accents (matches DS gold).
    private let gold = Color(hex: "E8B84B")

    init(moment: ShareMoment, theme: ShareTheme = .gold) {
        _model = StateObject(wrappedValue: ShareEditorModel(moment: moment, themeID: theme.id))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.Bg.base.ignoresSafeArea()

                VStack(spacing: 0) {
                    formatRow
                    previewArea
                    toolSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton }
                ToolbarItem(placement: .principal) {
                    Text(model.moment.kind.label.uppercased())
                        .font(.system(size: 15, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                ToolbarItem(placement: .topBarTrailing) { sharePill }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $model.showCaptionSheet) { captionSheet }
            .sheet(item: $exported) { item in
                ShareSheet(items: [item.image])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Top bar

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                Text("Back").font(.system(size: 16, weight: .regular))
            }
            .foregroundStyle(DS.Colors.Ink.primary)
        }
        .accessibilityLabel("Back")
    }

    private var sharePill: some View {
        Button {
            exportAndShare()
        } label: {
            Text(model.isExporting ? "Preparing…" : "Share")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "141005"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(gold)
                .clipShape(Capsule())
        }
        .disabled(model.isExporting)
    }

    // MARK: - Format row

    private var formatRow: some View {
        HStack(spacing: 10) {
            ForEach(ShareFormat.all) { format in
                formatChip(format)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s8)
        .padding(.bottom, DS.Spacing.s12)
    }

    private func formatChip(_ format: ShareFormat) -> some View {
        let active = model.formatID == format.id
        return Button {
            withAnimation(.easeOut(duration: 0.18)) { model.formatID = format.id }
        } label: {
            Text("\(format.name) \(format.ratio)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? gold : DS.Colors.Ink.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(active ? gold.opacity(0.16) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(active ? gold : Color.white.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Preview

    private var previewArea: some View {
        GeometryReader { geo in
            let format = model.format
            let scale = min(geo.size.width / format.width, geo.size.height / format.height)
            let onW = format.width * scale
            let onH = format.height * scale

            ZStack {
                // Static card base (no interactive chrome).
                MFShareCardV2(
                    moment: model.moment, theme: model.theme, format: format,
                    backdrop: model.backdrop, show: model.show,
                    photoAllowed: model.photoAllowed
                )
                .scaleEffect(scale, anchor: .center)
                .frame(width: onW, height: onH)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.5), radius: 24, y: 12)

                // Interactive overlays.
                EditorCanvas(model: model, onScreenSize: CGSize(width: onW, height: onH), scale: scale)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .bottom) { toastView }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.s20)
    }

    @ViewBuilder private var toastView: some View {
        if let toast = model.toast {
            Text(toast)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.86))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(gold.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Tool section (fixed height)

    private var toolSection: some View {
        VStack(spacing: 0) {
            Rectangle().fill(DS.Colors.Line.hairline).frame(height: 1)
            tray
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            tabBar
        }
        .background(DS.Colors.Bg.elevated)
    }

    @ViewBuilder private var tray: some View {
        switch model.activeTool {
        case .theme:    themeTray
        case .style:    styleTray
        case .text:     textTray
        case .stickers: stickerTray
        case .details:  detailsTray
        }
    }

    // MARK: - Theme tray

    private var themeTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(ShareTheme.all) { theme in
                    let active = model.themeID == theme.id
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { model.themeID = theme.id }
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(theme.bg)
                                .frame(width: 44, height: 44)
                                .overlay(Circle().fill(theme.accent).frame(width: 16, height: 16))
                                .overlay(
                                    Circle().stroke(active ? gold : Color.white.opacity(0.16),
                                                    lineWidth: active ? 3 : 1)
                                )
                            Text(theme.name)
                                .font(.system(size: 11, weight: active ? .bold : .medium))
                                .foregroundStyle(active ? gold : DS.Colors.Ink.tertiary)
                        }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Style tray

    private var styleTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ShareBackdrop.allCases) { backdrop in
                    styleChip(backdrop)
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .frame(maxHeight: .infinity)
        }
    }

    private func styleChip(_ backdrop: ShareBackdrop) -> some View {
        let active = model.backdrop == backdrop && !backdrop.isGated
        let locked = backdrop.isGated && !model.photoAllowed
        return Button {
            if locked {
                model.flashToast("Photo backgrounds need parent permission — ask a parent in Settings")
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else {
                withAnimation(.easeOut(duration: 0.18)) { model.backdrop = backdrop }
            }
        } label: {
            HStack(spacing: 6) {
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 11, weight: .semibold))
                }
                Text(backdrop.name)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(active ? gold : DS.Colors.Ink.tertiary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(active ? gold.opacity(0.16) : Color.white.opacity(0.05))
            .overlay(
                Capsule().stroke(active ? gold : Color.white.opacity(0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Text tray

    private var textTray: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    captionDraft = model.caption?.text ?? ""
                    model.showCaptionSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: model.hasCaption ? "pencil" : "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text(model.caption?.text ?? "Add caption")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(model.hasCaption ? gold : DS.Colors.Ink.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(model.hasCaption ? gold.opacity(0.16) : Color.white.opacity(0.05))
                    .overlay(
                        Capsule().stroke(model.hasCaption ? gold : Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())

                if model.hasCaption {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { model.removeCaption() }
                    } label: {
                        Text("Remove")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "F04A55"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .overlay(Capsule().stroke(Color(hex: "F04A55").opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            Text("Drag the caption anywhere on the card.")
                .font(.system(size: 12))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
    }

    // MARK: - Stickers tray

    private var stickerTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StickerPaletteItem.all) { item in
                    Button {
                        model.addSticker(item)
                    } label: {
                        stickerThumb(item)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .frame(maxHeight: .infinity)
        }
    }

    private func stickerThumb(_ item: StickerPaletteItem) -> some View {
        Group {
            switch item.kind {
            case let .text(label):
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(6)
                    .frame(width: 58, height: 58)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            case let .image(asset):
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .frame(width: 58, height: 58)
                    .background(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Details tray

    private var detailsTray: some View {
        VStack(spacing: 4) {
            detailToggle("Show my name & number", isOn: Binding(
                get: { model.show.name }, set: { model.show.name = $0 }
            ))
            detailToggle("Show stats", isOn: Binding(
                get: { model.show.stats }, set: { model.show.stats = $0 }
            ))
            detailToggle("Show date", isOn: Binding(
                get: { model.show.date }, set: { model.show.date = $0 }
            ))
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.vertical, DS.Spacing.s8)
    }

    private func detailToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn.animation(.easeOut(duration: 0.18))) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .tint(gold)
        .frame(height: 40)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(ShareEditorTool.allCases) { tool in
                let active = model.activeTool == tool
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { model.activeTool = tool }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tool.icon).font(.system(size: 16, weight: .semibold))
                        Text(tool.label).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(active ? gold : DS.Colors.Ink.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(active ? gold.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, DS.Spacing.s12)
        .padding(.top, 6)
        .padding(.bottom, DS.Spacing.s8)
    }

    // MARK: - Caption sheet

    private var captionSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                TextField("Say something…", text: $captionDraft, axis: .vertical)
                    .font(.system(size: 17, weight: .semibold))
                    .textInputAutocapitalization(.characters)
                    .lineLimit(2, reservesSpace: true)
                    .padding(DS.Spacing.s16)
                    .background(DS.Colors.Bg.card)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .onChange(of: captionDraft) { _, newValue in
                        if newValue.count > 40 { captionDraft = String(newValue.prefix(40)) }
                    }

                Text("\(captionDraft.count)/40")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.Colors.Ink.quaternary)

                Spacer()
            }
            .padding(DS.Spacing.s20)
            .background(DS.Colors.Bg.base)
            .navigationTitle("Caption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { model.showCaptionSheet = false }
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add to card") {
                        model.setCaption(captionDraft)
                        model.showCaptionSheet = false
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(gold)
                    .disabled(captionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationDetents([.height(260)])
    }

    // MARK: - Export

    private func exportAndShare() {
        guard !model.isExporting else { return }
        model.deselect()
        model.isExporting = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let composite = ShareCardComposite(
            moment: model.moment, theme: model.theme, format: model.format,
            backdrop: model.backdrop, show: model.show,
            caption: model.caption, stickers: model.stickers,
            photoAllowed: model.photoAllowed
        )
        let image = ShareCardRenderer.renderCard(composite, format: model.format)
        model.isExporting = false
        if let image { exported = ShareableImage(image: image) }
    }
}

// MARK: - Interactive canvas

/// The overlay layer that hosts draggable / resizable stickers and the caption.
/// Sized to match the on-screen card so unit-fraction positions map directly to
/// screen points. Tapping empty space deselects.
private struct EditorCanvas: View {
    @ObservedObject var model: ShareEditorModel
    let onScreenSize: CGSize
    let scale: CGFloat

    static let space = "editorCanvas"

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { model.deselect() } }

            ForEach(model.stickers) { sticker in
                StickerItem(model: model, sticker: sticker, canvas: onScreenSize, scale: scale)
            }

            if let caption = model.caption {
                CaptionItem(model: model, caption: caption, theme: model.theme,
                            canvas: onScreenSize, scale: scale)
            }
        }
        .frame(width: onScreenSize.width, height: onScreenSize.height)
        .coordinateSpace(name: Self.space)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Sticker item

private struct StickerItem: View {
    @ObservedObject var model: ShareEditorModel
    let sticker: EditorSticker
    let canvas: CGSize
    let scale: CGFloat

    @State private var moveStart: CGPoint?
    @State private var resizeStartRadius: CGFloat?
    @State private var resizeStartScale: CGFloat?

    private let gold = Color(hex: "E8B84B")

    private var isSelected: Bool { model.selectedStickerID == sticker.id }
    private var center: CGPoint {
        CGPoint(x: sticker.x * canvas.width, y: sticker.y * canvas.height)
    }

    var body: some View {
        ShareStickerContent(sticker: sticker, renderScale: scale)
            .overlay { if isSelected { outline } }
            .overlay(alignment: .topLeading) { if isSelected { deleteButton } }
            .overlay(alignment: .bottomTrailing) { if isSelected { resizeHandle } }
            .position(center)
            .gesture(moveGesture)
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.15)) { model.select(sticker.id) }
            }
    }

    private var outline: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(gold, lineWidth: 2.5)
            .padding(-8)
    }

    private var deleteButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { model.removeSticker(sticker.id) }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.black.opacity(0.82)))
                .overlay(Circle().stroke(gold, lineWidth: 1.5))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .offset(x: -22, y: -22)
        .accessibilityLabel("Delete sticker")
    }

    private var resizeHandle: some View {
        Circle()
            .fill(gold)
            .frame(width: 26, height: 26)
            .overlay(
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
            )
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .offset(x: 22, y: 22)
            .highPriorityGesture(resizeGesture)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(EditorCanvas.space))
            .onChanged { value in
                if moveStart == nil {
                    moveStart = CGPoint(x: sticker.x, y: sticker.y)
                    model.select(sticker.id)
                }
                guard let start = moveStart else { return }
                let dx = value.translation.width / canvas.width
                let dy = value.translation.height / canvas.height
                model.moveSticker(sticker.id, x: start.x + dx, y: start.y + dy)
            }
            .onEnded { _ in moveStart = nil }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(EditorCanvas.space))
            .onChanged { value in
                let c = center
                let r = max(1, hypot(value.location.x - c.x, value.location.y - c.y))
                if resizeStartRadius == nil {
                    resizeStartRadius = r
                    resizeStartScale = sticker.scale
                }
                guard let r0 = resizeStartRadius, let s0 = resizeStartScale else { return }
                model.scaleSticker(sticker.id, scale: s0 * (r / r0))
            }
            .onEnded { _ in
                resizeStartRadius = nil
                resizeStartScale = nil
            }
    }
}

// MARK: - Caption item

private struct CaptionItem: View {
    @ObservedObject var model: ShareEditorModel
    let caption: EditorCaption
    let theme: ShareTheme
    let canvas: CGSize
    let scale: CGFloat

    @State private var moveStart: CGPoint?

    var body: some View {
        ShareCaptionContent(text: caption.text, theme: theme, renderScale: scale)
            .frame(maxWidth: canvas.width * 0.9)
            .position(x: caption.x * canvas.width, y: caption.y * canvas.height)
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named(EditorCanvas.space))
                    .onChanged { value in
                        if moveStart == nil { moveStart = CGPoint(x: caption.x, y: caption.y) }
                        guard let start = moveStart else { return }
                        let dx = value.translation.width / canvas.width
                        let dy = value.translation.height / canvas.height
                        model.moveCaption(x: start.x + dx, y: start.y + dy)
                    }
                    .onEnded { _ in moveStart = nil }
            )
    }
}

#Preview {
    ShareEditorView(moment: .sample(.combineResult))
        .preferredColorScheme(.dark)
}
