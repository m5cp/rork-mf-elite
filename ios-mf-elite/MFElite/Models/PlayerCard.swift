//
//  PlayerCard.swift
//  MFElite
//
//  The data model behind the shareable, Instagram-style editable player card.
//  A `CardDesign` is fully local and Codable so it can be persisted between
//  sessions. The same model drives both the on-screen editor and the
//  high-resolution image export.
//

import SwiftUI

/// A Codable point stored in normalized 0...1 card space so it scales cleanly
/// from the small editor canvas up to the full-resolution export.
nonisolated struct NormalizedPoint: Codable, Equatable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

/// A free-form text sticker the player drops onto the card. Positions and size
/// are normalized so they render identically at any export resolution.
nonisolated struct CardTextOverlay: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    /// Center position in normalized card space (0...1).
    var x: Double
    var y: Double
    /// Font size as a fraction of card width (e.g. 0.10 = 10% of width).
    var sizeFraction: Double
    var colorHex: String
    var isBold: Bool
    /// Rotation in radians.
    var rotation: Double

    init(
        id: UUID = UUID(),
        text: String,
        x: Double = 0.5,
        y: Double = 0.5,
        sizeFraction: Double = 0.10,
        colorHex: String = "FFFFFF",
        isBold: Bool = true,
        rotation: Double = 0
    ) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.sizeFraction = sizeFraction
        self.colorHex = colorHex
        self.isBold = isBold
        self.rotation = rotation
    }
}

/// A single free-hand pen stroke, captured as normalized points.
nonisolated struct CardStroke: Identifiable, Codable, Equatable {
    var id: UUID
    var points: [NormalizedPoint]
    var colorHex: String
    /// Line width as a fraction of card width.
    var widthFraction: Double

    init(id: UUID = UUID(), points: [NormalizedPoint], colorHex: String, widthFraction: Double) {
        self.id = id
        self.points = points
        self.colorHex = colorHex
        self.widthFraction = widthFraction
    }
}

/// Background palettes for the card. Each defines a gradient and an accent.
nonisolated enum CardTheme: String, Codable, CaseIterable, Identifiable {
    case noir
    case gold
    case crimson
    case emerald
    case royal
    case ice
    case sunset
    // Photographic backdrops. New cases only ever get appended — the raw
    // value is what's persisted in a player's saved card, so renaming or
    // reordering would silently reset cards that are already out there.
    case dawn
    case rooftop
    case desert
    case holo
    case emblem
    case frosted
    case monolith

    nonisolated var id: String { rawValue }

    var name: String {
        switch self {
        case .noir: return "Noir"
        case .gold: return "Gold"
        case .crimson: return "Crimson"
        case .emerald: return "Emerald"
        case .royal: return "Royal"
        case .ice: return "Ice"
        case .sunset: return "Sunset"
        case .dawn: return "Dawn"
        case .rooftop: return "Rooftop"
        case .desert: return "Desert"
        case .holo: return "Holo"
        case .emblem: return "Emblem"
        case .frosted: return "Frosted"
        case .monolith: return "Monolith"
        }
    }

    /// Asset-catalog name of the backdrop photograph, for the photographic
    /// themes. `nil` means the theme is a pure gradient.
    var imageName: String? {
        switch self {
        case .dawn:     return "card_dawn"
        case .rooftop:  return "card_rooftop"
        case .desert:   return "card_desert"
        case .holo:     return "card_holo"
        case .emblem:   return "card_emblem"
        case .frosted:  return "card_frosted"
        case .monolith: return "card_monolith"
        default:        return nil
        }
    }

    /// Swatch-sized copy of the backdrop, for the theme picker. The picker
    /// builds every swatch at once, and seven full-size card images would be
    /// tens of megabytes of decoded bitmap to draw seven 48pt tiles.
    var thumbName: String? { imageName.map { $0 + "_thumb" } }

    /// A card saved by a newer build can carry a theme this build has never
    /// heard of. Falling back to Noir keeps the rest of the design — every
    /// text sticker and pen stroke — instead of letting the decode throw and
    /// taking the whole card with it.
    nonisolated init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CardTheme(rawValue: raw) ?? .noir
    }

    /// Gradient stops, dark → darker for legibility.
    var gradientHex: [String] {
        switch self {
        case .noir:    return ["1C1C1E", "0A0A0A", "000000"]
        case .gold:    return ["3D2E0A", "171206", "000000"]
        case .crimson: return ["3A0C12", "180407", "000000"]
        case .emerald: return ["07301F", "041610", "000000"]
        case .royal:   return ["171347", "0A0824", "000000"]
        case .ice:     return ["10303A", "081A20", "000000"]
        case .sunset:  return ["3D1505", "1E0A03", "000000"]
        // Sit under the photograph as a matching base, so the card still
        // reads correctly for the instant before the image decodes.
        case .dawn:     return ["2E2419", "12100C", "000000"]
        case .rooftop:  return ["10132E", "080A18", "000000"]
        case .desert:   return ["2A2013", "12100A", "000000"]
        case .holo:     return ["0C2430", "06131A", "000000"]
        case .emblem:   return ["16181A", "0A0B0C", "000000"]
        case .frosted:  return ["101214", "07080A", "000000"]
        case .monolith: return ["1A1C1E", "0B0C0D", "000000"]
        }
    }

    /// Accent color used for the rank pill, name underline, and details.
    var accentHex: String {
        switch self {
        case .noir:    return "FFFFFF"
        case .gold:    return "F5C84B"
        case .crimson: return "FF453A"
        case .emerald: return "30D158"
        case .royal:   return "5E5CE6"
        case .ice:     return "64D2FF"
        case .sunset:  return "FF9F0A"
        case .dawn:     return "F0B15A"
        case .rooftop:  return "7DE3FF"
        case .desert:   return "F5C84B"
        case .holo:     return "64D2FF"
        case .emblem:   return "D8DDE3"
        case .frosted:  return "FFFFFF"
        case .monolith: return "C9CFD6"
        }
    }

    var accent: Color { Color(hex: accentHex) }

    var gradientColors: [Color] { gradientHex.map { Color(hex: $0) } }
}

/// The complete, persisted description of a player's card design.
nonisolated struct CardDesign: Codable, Equatable {
    var theme: CardTheme
    /// True when the player has set a custom background photo (stored on disk).
    var hasPhoto: Bool
    /// Show the built-in name / rank / stat plate on top of the background.
    var showStatPlate: Bool
    var overlays: [CardTextOverlay]
    var strokes: [CardStroke]

    init(
        theme: CardTheme = .noir,
        hasPhoto: Bool = false,
        showStatPlate: Bool = true,
        overlays: [CardTextOverlay] = [],
        strokes: [CardStroke] = []
    ) {
        self.theme = theme
        self.hasPhoto = hasPhoto
        self.showStatPlate = showStatPlate
        self.overlays = overlays
        self.strokes = strokes
    }
}

/// Snapshot of the live player data the card renders. Built from the profile +
/// player state at present time and passed into the canvas.
nonisolated struct CardPlayerInfo: Equatable {
    var name: String
    var rankNumeral: String
    var rankTitle: String
    var xp: Int
    var streak: Int
    var position: String
    /// Short position code shown on the card (e.g. "ST").
    var positionCode: String
    var kitNumber: String
    /// Preferred foot label.
    var foot: String
    /// Class year text (e.g. "2029" or "—").
    var classYearText: String
    var academy: String
    var initials: String
    /// Avatar selection so the card photo box mirrors the profile avatar.
    var avatar: AvatarSelection
}

/// Palette of pen / text colors offered in the editor.
nonisolated enum CardPalette {
    static let hexes: [String] = [
        "FFFFFF", "000000", "FF453A", "FF9F0A", "F5C84B",
        "30D158", "64D2FF", "5E5CE6", "BF5AF2", "FF6482"
    ]
}
