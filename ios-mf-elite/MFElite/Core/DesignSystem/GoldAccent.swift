//
// GoldAccent.swift
// MFElite
//
// ── ELITE ACCENT SYSTEM (user-selectable) ──
// The app stays black & white; ONE accent color appears on symbols & icons,
// hero-card frame edges, avatar/monogram rings, and progress fills.
// The accent is user-selectable (Settings → Accent Color). The DS.Colors.Gold
// token names are kept for compatibility — they resolve to the CURRENT accent.
//
// READABILITY RULES (non-negotiable, per accent):
// • Small accent TYPE always uses .textLight at FULL opacity.
// • Accent text only at micro/eyebrow scale or tag chips. Body, titles and
// numerals stay white.
// • Never accent-on-accent. Solid accent chips use the accent's dark inkOnGold.
// Every AppAccent below ships its own light text variant, dark ink, and
// 5-stop metallic ramp — all pre-checked for contrast on #000.
//

import SwiftUI

// MARK: - Selectable accents

/// The user-selectable accent palettes. Persisted under the "MF_ACCENT" key
/// (see PlayerProfileStore.accentID). Every palette is tuned for a black
/// background: a mid-tone base for icons/fills, a guaranteed-light text
/// variant, a dark ink for text on solid accent, and a 5-stop metallic ramp.
enum AppAccent: String, CaseIterable, Identifiable {
    case gold, silver, royal, crimson, pitch

    var id: String { rawValue }

    static let storageKey = "MF_ACCENT"

    /// The currently selected accent (synchronous read so Canvas draw code can
    /// resolve it at paint time).
    static var current: AppAccent {
        AppAccent(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .gold
    }

    var displayName: String {
        switch self {
        case .gold: return "Elite Gold"
        case .silver: return "Silver"
        case .royal: return "Royal"
        case .crimson: return "Crimson"
        case .pitch: return "Pitch"
        }
    }

    /// Primary accent — icon strokes, fills, chips, active tab.
    var base: Color {
        switch self {
        case .gold: return Color(hex: "#E8B84B")
        case .silver: return Color(hex: "#C3CBD3")
        case .royal: return Color(hex: "#5B8DEF")
        case .crimson: return Color(hex: "#E4574F")
        case .pitch: return Color(hex: "#3FBF6F")
        }
    }

    /// Light variant — small TEXT and gradient highlights. Full opacity only.
    var textLight: Color {
        switch self {
        case .gold: return Color(hex: "#F6D98A")
        case .silver: return Color(hex: "#EDF1F5")
        case .royal: return Color(hex: "#A9C4FA")
        case .crimson: return Color(hex: "#F5A29D")
        case .pitch: return Color(hex: "#9FE8BC")
        }
    }

    /// Dark ink for text sitting ON a solid accent fill.
    var inkOnAccent: Color {
        switch self {
        case .gold: return Color(hex: "#141005")
        case .silver: return Color(hex: "#10141A")
        case .royal: return Color(hex: "#0A1024")
        case .crimson: return Color(hex: "#230807")
        case .pitch: return Color(hex: "#06180D")
        }
    }

    /// 5-stop metallic ramp, light → dark (3-D sheen for symbols/icons).
    var rampColors: [Color] {
        switch self {
        case .gold: return [
            Color(hex: "#FFF7D6"), Color(hex: "#F8DE95"), Color(hex: "#E8B84B"),
            Color(hex: "#B07E1E"), Color(hex: "#795310")
        ]
        case .silver: return [
            Color(hex: "#FFFFFF"), Color(hex: "#EDF1F5"), Color(hex: "#C3CBD3"),
            Color(hex: "#899099"), Color(hex: "#586069")
        ]
        case .royal: return [
            Color(hex: "#E3EDFF"), Color(hex: "#A9C4FA"), Color(hex: "#5B8DEF"),
            Color(hex: "#2F5BC0"), Color(hex: "#1B3775")
        ]
        case .crimson: return [
            Color(hex: "#FFE3E1"), Color(hex: "#F5A29D"), Color(hex: "#E4574F"),
            Color(hex: "#B03028"), Color(hex: "#6E1B16")
        ]
        case .pitch: return [
            Color(hex: "#DFF7E8"), Color(hex: "#9FE8BC"), Color(hex: "#3FBF6F"),
            Color(hex: "#1F8C4A"), Color(hex: "#115229")
        ]
        }
    }
}

// MARK: - Tokens (names preserved; values resolve from the selected accent)

extension DS.Colors {
    enum Gold {
        /// Primary accent — icon strokes, fills, chips, active tab.
        static var base: Color { AppAccent.current.base }
        /// Light accent — small TEXT and gradient highlights. Full opacity only.
        static var textLight: Color { AppAccent.current.textLight }
        /// Hairline borders, chevrons, completed rails.
        static var line: Color { AppAccent.current.base.opacity(0.50) }
        /// Tinted fills (active lens backgrounds).
        static var soft: Color { AppAccent.current.base.opacity(0.14) }
        /// Ambient glow / halo.
        static var faint: Color { AppAccent.current.base.opacity(0.07) }
        /// Dark ink for text sitting ON a solid accent fill.
        static var inkOnGold: Color { AppAccent.current.inkOnAccent }

        /// Progress bars & pips: accent → light accent, left to right.
        static var progressGradient: LinearGradient {
            LinearGradient(colors: [base, textLight], startPoint: .leading, endPoint: .trailing)
        }

        /// Metallic frame-edge gradient (140° ≈ topLeading → bottomTrailing).
        static var edgeGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: textLight, location: 0.00),
                    .init(color: base.opacity(0.60), location: 0.26),
                    .init(color: Color.white.opacity(0.12), location: 0.55),
                    .init(color: base.opacity(0.45), location: 1.00),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// Metallic accent for symbols/icons — light top to dark base (3-D sheen).
        static var symbolGradient: LinearGradient {
            LinearGradient(colors: AppAccent.current.rampColors, startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Silver tokens (secondary metal — fixed, not user-selectable)

extension DS.Colors {
    enum Silver {
        static let base = Color(hex: "#C3CBD3")
        static let textLight = Color(hex: "#EDF1F5")
        static let line = Color(hex: "#C3CBD3").opacity(0.50)

        /// Metallic silver for secondary/utility symbols & icons.
        static let symbolGradient = LinearGradient(
            colors: [
                Color(hex: "#FFFFFF"), Color(hex: "#EDF1F5"), Color(hex: "#C3CBD3"),
                Color(hex: "#899099"), Color(hex: "#586069")
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Metallic symbol modifier

/// A 3-D metallic finish (accent or silver) for an SF Symbol / image: a top-lit
/// metal gradient plus a soft drop shadow for lift.
/// How symbols and avatars are finished across the app.
///
/// The accent hue is already user-selectable; this is the second axis the
/// owner asked for — whether identity symbols pick the accent up at all, or
/// stay monochrome. Some people want a gold app; some want black-and-white
/// with gold used sparingly. Persisted alongside the accent.
enum SymbolStyle: String, CaseIterable, Identifiable {
    /// Icons, avatars, badges and seals take the accent. Default.
    case accent
    /// Everything stays white/ink; the accent appears only on progress fills
    /// and selection states, where it carries meaning rather than decoration.
    case monochrome

    var id: String { rawValue }

    static let storageKey = "MF_SYMBOL_STYLE"

    /// Read synchronously so Canvas / paint-time code can resolve it.
    static var current: SymbolStyle {
        SymbolStyle(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .accent
    }

    var displayName: String {
        switch self {
        case .accent:     return "Accent"
        case .monochrome: return "Monochrome"
        }
    }

    var detail: String {
        switch self {
        case .accent:     return "Icons, avatars and badges use your accent color."
        case .monochrome: return "Icons and avatars stay white. Accent is kept for progress and selection."
        }
    }
}

struct MetallicSymbol: ViewModifier {
    enum Finish { case gold, silver }
    var finish: Finish = .gold

    func body(content: Content) -> some View {
        content
            .foregroundStyle(shading)
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1.5)
    }

    /// Honors the user's symbol-style preference. In monochrome the symbol
    /// keeps the metallic depth but drops to a neutral ramp, so the finish
    /// still reads as deliberate rather than flat white.
    private var shading: LinearGradient {
        guard SymbolStyle.current == .accent else { return DS.Colors.Silver.symbolGradient }
        return finish == .gold ? DS.Colors.Gold.symbolGradient : DS.Colors.Silver.symbolGradient
    }
}

extension View {
    /// Metallic accent (default) or silver finish for a symbol / icon.
    func metallicSymbol(_ finish: MetallicSymbol.Finish = .gold) -> some View {
        modifier(MetallicSymbol(finish: finish))
    }
}

// MARK: - Gold edge (hero cards) — the signature move

struct GoldEdge: ViewModifier {
    var cornerRadius: CGFloat = 26

    func body(content: Content) -> some View {
        content
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous))
            // inner bevel
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .blendMode(.plusLighter)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            )
            .padding(1)
            // 1px metallic gradient frame
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DS.Colors.Gold.edgeGradient)
            )
            // 3D lift: contact + ambient + accent halo
            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            .shadow(color: .black.opacity(0.58), radius: 28, y: 24)
            .shadow(color: DS.Colors.Gold.faint, radius: 20)
    }
}

extension View {
    /// Wrap a hero card in the accent metallic frame with 3D lift.
    func goldEdge(cornerRadius: CGFloat = 26) -> some View {
        modifier(GoldEdge(cornerRadius: cornerRadius))
    }
}

// MARK: - Gold ring (avatars)

struct GoldRing: ViewModifier {
    var shape: AnyShape = AnyShape(Circle())

    func body(content: Content) -> some View {
        content
            .overlay(shape.stroke(Color.black, lineWidth: 3).padding(1.5))
            .overlay(shape.stroke(DS.Colors.Gold.textLight.opacity(0.40), lineWidth: 1).padding(3.5))
            .overlay(shape.stroke(DS.Colors.Gold.symbolGradient, lineWidth: 2))
            .shadow(color: .black.opacity(0.55), radius: 5, y: 4)
            .shadow(color: DS.Colors.Gold.base.opacity(0.22), radius: 7)
    }
}

extension View {
    /// Accent avatar ring: outer accent line, black gap, inner light echo, soft lift + glow.
    func goldRing(shape: AnyShape = AnyShape(Circle())) -> some View {
        modifier(GoldRing(shape: shape))
    }
}
