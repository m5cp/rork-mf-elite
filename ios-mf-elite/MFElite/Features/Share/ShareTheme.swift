//
//  ShareTheme.swift
//  MFElite
//
//  Design tokens for the shareable-card system: the 5 card themes, the 3 export
//  formats, and the 4 backdrops. All card sizes are expressed in design px at a
//  1080-wide export resolution, matching the design handoff exactly.
//

import SwiftUI

// MARK: - Theme

/// A full-bleed card palette. Values mirror the handoff Themes table 1:1.
struct ShareTheme: Identifiable, Equatable {
    let id: String
    let name: String
    /// Card background.
    let bg: Color
    /// Primary text.
    let ink: Color
    /// Secondary / muted text (player line, dates, labels).
    let sub: Color
    /// The theme's signal color (numerals, chips, bars).
    let accent: Color
    /// A lighter accent for gradients / highlights.
    let accent2: Color
    /// Ink color that reads on top of `accent` (eyebrow / caption chips).
    let chipInk: Color

    /// The light "Whiteout" theme flips a few neutral fills to black.
    var isLight: Bool { id == "white" }

    /// Neutral fill used for stat cells and progress-bar tracks.
    func neutralFill(_ opacity: Double) -> Color {
        (isLight ? Color.black : Color.white).opacity(opacity)
    }

    static let all: [ShareTheme] = [
        ShareTheme(
            id: "gold", name: "Elite Gold",
            bg: Color(hex: "050505"), ink: .white, sub: .white.opacity(0.55),
            accent: Color(hex: "E8B84B"), accent2: Color(hex: "F6D98A"), chipInk: Color(hex: "141005")
        ),
        ShareTheme(
            id: "white", name: "Whiteout",
            bg: Color(hex: "F4F3EF"), ink: Color(hex: "0A0A0A"), sub: Color(hex: "0A0A0A").opacity(0.55),
            accent: Color(hex: "0A0A0A"), accent2: Color(hex: "3A3A3A"), chipInk: Color(hex: "F4F3EF")
        ),
        ShareTheme(
            id: "royal", name: "Royal",
            bg: Color(hex: "06080F"), ink: .white, sub: .white.opacity(0.55),
            accent: Color(hex: "4D82FF"), accent2: Color(hex: "8FB0FF"), chipInk: Color(hex: "060B1A")
        ),
        ShareTheme(
            id: "crimson", name: "Crimson",
            bg: Color(hex: "0F0507"), ink: .white, sub: .white.opacity(0.55),
            accent: Color(hex: "F04A55"), accent2: Color(hex: "FF8B93"), chipInk: Color(hex: "1A0608")
        ),
        ShareTheme(
            id: "pitch", name: "Pitch",
            bg: Color(hex: "04100A"), ink: .white, sub: .white.opacity(0.55),
            accent: Color(hex: "37C978"), accent2: Color(hex: "7FE3AB"), chipInk: Color(hex: "04140B")
        ),
    ]

    static let gold = all[0]

    static func theme(id: String) -> ShareTheme {
        all.first { $0.id == id } ?? gold
    }
}

// MARK: - Format

/// An export size. Width is always 1080 (the design resolution).
struct ShareFormat: Identifiable, Equatable {
    let id: String
    let name: String
    let ratio: String
    let width: CGFloat
    let height: CGFloat

    /// Vertical rhythm between body elements, per the handoff.
    var bodyGap: CGFloat {
        switch id {
        case "story":    return 56
        case "portrait": return 44
        default:         return 34
        }
    }

    static let story = ShareFormat(id: "story", name: "Story", ratio: "9:16", width: 1080, height: 1920)
    static let portrait = ShareFormat(id: "portrait", name: "Post", ratio: "4:5", width: 1080, height: 1350)
    static let square = ShareFormat(id: "square", name: "Square", ratio: "1:1", width: 1080, height: 1080)

    static let all: [ShareFormat] = [story, portrait, square]

    static func format(id: String) -> ShareFormat {
        all.first { $0.id == id } ?? story
    }
}

// MARK: - Backdrop

/// The four card backgrounds. `photo` is parent-gated in later phases.
enum ShareBackdrop: String, CaseIterable, Identifiable {
    case solid
    case glow
    case pitch
    case photo

    var id: String { rawValue }

    var name: String {
        switch self {
        case .solid: return "Solid"
        case .glow:  return "Glow"
        case .pitch: return "Pitch"
        case .photo: return "My Photo"
        }
    }

    /// Whether this backdrop requires parent permission (photo backgrounds).
    var isGated: Bool { self == .photo }
}

// MARK: - Show toggles

/// Per-card visibility toggles for the private / optional lines.
struct ShareShow: Equatable {
    var name: Bool = true
    var stats: Bool = true
    var date: Bool = true
}
