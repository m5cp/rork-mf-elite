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
        }
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
