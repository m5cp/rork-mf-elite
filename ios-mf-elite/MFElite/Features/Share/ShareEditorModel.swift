//
//  ShareEditorModel.swift
//  MFElite
//
//  Editable state for the share editor. Everything a player can tweak before
//  sharing a card lives here: format, theme, backdrop, the private detail
//  toggles, an optional caption chip, and a stack of stickers. All on-card
//  positions are stored as unit fractions (0–1) of the card size so they
//  survive format switches and export at any resolution.
//

import SwiftUI
import Combine

// MARK: - Editor tools

/// The five bottom tabs of the editor, each with its own tray.
enum ShareEditorTool: String, CaseIterable, Identifiable {
    case theme
    case style
    case text
    case stickers
    case details

    var id: String { rawValue }

    var label: String {
        switch self {
        case .theme:    return "Theme"
        case .style:    return "Style"
        case .text:     return "Text"
        case .stickers: return "Stickers"
        case .details:  return "Details"
        }
    }

    var icon: String {
        switch self {
        case .theme:    return "paintpalette.fill"
        case .style:    return "photo.fill"
        case .text:     return "textformat"
        case .stickers: return "face.smiling.fill"
        case .details:  return "slider.horizontal.3"
        }
    }
}

// MARK: - Sticker & caption

/// A sticker's content — either a short text chip or a first-party image.
enum EditorStickerKind: Equatable {
    case text(String)
    case image(String) // asset-catalog name
}

/// A sticker placed on the card. `x`/`y` are unit fractions of the card size;
/// `scale` multiplies the sticker's base design size; `rotation` is degrees.
struct EditorSticker: Identifiable, Equatable {
    let id: UUID
    var kind: EditorStickerKind
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var rotation: Double

    /// Base design size for image stickers (design px at 1080-wide export).
    static let imageBase: CGFloat = 280
    /// Base display font size for text stickers.
    static let textBase: CGFloat = 58

    init(id: UUID = UUID(), kind: EditorStickerKind, x: CGFloat, y: CGFloat, scale: CGFloat = 1, rotation: Double) {
        self.id = id
        self.kind = kind
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
    }
}

/// The single optional caption chip. `x`/`y` are unit fractions of the card.
struct EditorCaption: Equatable {
    var text: String
    var x: CGFloat = 0.5
    var y: CGFloat = 0.8
}

// MARK: - Sticker catalog

/// A pickable sticker in the Stickers tray. Text stickers show their label;
/// image stickers show their catalog art.
struct StickerPaletteItem: Identifiable, Equatable {
    let id: String
    let kind: EditorStickerKind

    /// The four text stickers followed by six first-party image stickers,
    /// mapped to the existing asset-catalog names (no new images).
    static let all: [StickerPaletteItem] = [
        StickerPaletteItem(id: "st-pb",      kind: .text("PERSONAL BEST")),
        StickerPaletteItem(id: "st-fire",    kind: .text("ON FIRE")),
        StickerPaletteItem(id: "st-nodays",  kind: .text("NO DAYS OFF")),
        StickerPaletteItem(id: "st-clutch",  kind: .text("CLUTCH")),
        StickerPaletteItem(id: "st-golazo",  kind: .text("GOLAZO")),
        StickerPaletteItem(id: "st-ball",    kind: .image("SoccerBall")),
        StickerPaletteItem(id: "st-flame",   kind: .image("medal_flame_badge_7")),
        StickerPaletteItem(id: "st-soccmed", kind: .image("soccer_medal_badge")),
        StickerPaletteItem(id: "st-dawn",    kind: .image("medal_football_dawn")),
        StickerPaletteItem(id: "st-ten",     kind: .image("medal_badge_10_soccer")),
        StickerPaletteItem(id: "st-mf",      kind: .image("mf-logo-white")),
    ]
}

// MARK: - Model

/// All editable + transient state for `ShareEditorView`.
@MainActor
final class ShareEditorModel: ObservableObject {
    /// The moment being edited (its body content is fixed; chrome is editable).
    let moment: ShareMoment

    // Persistent card state.
    @Published var formatID: String
    @Published var themeID: String
    @Published var backdrop: ShareBackdrop = .glow
    @Published var show = ShareShow()
    @Published var caption: EditorCaption?
    @Published var stickers: [EditorSticker] = []
    @Published var selectedStickerID: UUID?

    /// Parent permission for photo backdrops. Sourced from `SharePhotoPermission`
    /// (a parent-gated, per-athlete grant). When `false`, My Photo stays locked.
    @Published var photoAllowed: Bool = SharePhotoPermission.shared.isGranted
    /// The picked photo used by the `.photo` backdrop, when allowed.
    @Published var photo: UIImage?

    // Transient UI state.
    @Published var activeTool: ShareEditorTool = .theme
    @Published var isExporting = false
    @Published var toast: String?
    @Published var showCaptionSheet = false

    private var toastToken = 0

    init(moment: ShareMoment, formatID: String = ShareFormat.story.id, themeID: String = ShareTheme.gold.id) {
        self.moment = moment
        self.formatID = formatID
        self.themeID = themeID
    }

    // MARK: - Derived

    var format: ShareFormat { ShareFormat.format(id: formatID) }
    var theme: ShareTheme { ShareTheme.theme(id: themeID) }
    var hasCaption: Bool { caption != nil }

    // MARK: - Stickers

    /// Adds a sticker at the upper-center with a slight random tilt.
    func addSticker(_ item: StickerPaletteItem) {
        let sticker = EditorSticker(
            kind: item.kind,
            x: 0.5,
            y: 0.32,
            scale: 1,
            rotation: Double.random(in: -5...5)
        )
        stickers.append(sticker)
        selectedStickerID = sticker.id
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func select(_ id: UUID) {
        if selectedStickerID != id { selectedStickerID = id }
    }

    func deselect() {
        if selectedStickerID != nil { selectedStickerID = nil }
    }

    func removeSticker(_ id: UUID) {
        stickers.removeAll { $0.id == id }
        if selectedStickerID == id { selectedStickerID = nil }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// Moves a sticker, clamping into the safe on-card area.
    func moveSticker(_ id: UUID, x: CGFloat, y: CGFloat) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[index].x = Self.clampPosition(x)
        stickers[index].y = Self.clampPosition(y)
    }

    /// Scales a sticker within the allowed range.
    func scaleSticker(_ id: UUID, scale: CGFloat) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[index].scale = min(2.4, max(0.35, scale))
    }

    // MARK: - Caption

    func setCaption(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { caption = nil; return }
        if var existing = caption {
            existing.text = trimmed
            caption = existing
        } else {
            caption = EditorCaption(text: trimmed)
        }
    }

    func removeCaption() {
        caption = nil
    }

    // MARK: - Photo backdrop

    /// Records the parent's grant and unlocks photo backdrops for this athlete.
    func grantPhotoPermission() {
        SharePhotoPermission.shared.grant()
        photoAllowed = true
    }

    /// Sets the picked photo and switches the card to the photo backdrop.
    func setPhoto(_ image: UIImage) {
        photo = image
        backdrop = .photo
    }

    func moveCaption(x: CGFloat, y: CGFloat) {
        guard caption != nil else { return }
        caption?.x = Self.clampPosition(x)
        caption?.y = Self.clampPosition(y)
    }

    // MARK: - Toast

    /// Flashes a transient toast message that auto-dismisses.
    func flashToast(_ message: String) {
        toast = message
        toastToken += 1
        let token = toastToken
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard let self, self.toastToken == token else { return }
            withAnimation { self.toast = nil }
        }
    }

    // MARK: - Helpers

    /// Positions are unit fractions clamped so a sticker never leaves the card.
    static func clampPosition(_ value: CGFloat) -> CGFloat {
        min(0.96, max(0.04, value))
    }
}
