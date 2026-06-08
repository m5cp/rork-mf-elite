//
//  DesignSystem.swift
//  MFElite
//
//  Complete design system namespace. All values final — match exactly.
//

import SwiftUI

// MARK: - Color Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - DS Namespace

enum DS {

    // MARK: - Colors

    enum Colors {
        enum Bg {
            static let base = Color(hex: "#000000")
            static let elevated = Color(hex: "#0A0A0A")
            static let card = Color(hex: "#121212")
            static let raised = Color(hex: "#1A1A1A")
            static let tint = Color(hex: "#262626")
        }

        enum Line {
            static let hairline = Color.white.opacity(0.15)
            static let subtle = Color.white.opacity(0.20)
            static let strong = Color.white.opacity(0.34)
        }

        enum Ink {
            static let primary = Color.white
            static let secondary = Color.white.opacity(0.90)
            static let tertiary = Color.white.opacity(0.72)
            static let quaternary = Color.white.opacity(0.52)
            static let disabled = Color.white.opacity(0.32)
        }

        enum Ground {
            static let primary = Color.black
            static let secondary = Color.black.opacity(0.62)
            static let tertiary = Color.black.opacity(0.40)
        }
    }

    // MARK: - Typography

    enum Typography {
        static let hero: Font = .system(size: 48, weight: .heavy)
        static let display: Font = .system(size: 36, weight: .heavy)
        static let title1: Font = .system(size: 28, weight: .bold)
        static let title2: Font = .system(size: 22, weight: .bold)
        static let title3: Font = .system(size: 17, weight: .semibold)
        static let body: Font = .system(size: 16, weight: .regular)
        static let callout: Font = .system(size: 15, weight: .medium)
        static let foot: Font = .system(size: 13, weight: .medium)
        static let cap: Font = .system(size: 11, weight: .medium)
        static let micro: Font = .system(size: 10, weight: .medium, design: .monospaced)
        static let microSm: Font = .system(size: 9, weight: .medium, design: .monospaced)

        static func num(size: CGFloat) -> Font {
            .system(size: size, weight: .bold).monospacedDigit()
        }
    }

    /// Text style presets that apply font + tracking + case all at once.
    enum TextStyle {
        case hero
        case display
        case title1
        case title2
        case title3
        case body
        case callout
        case foot
        case cap
        case micro
        case microSm
        case num(size: CGFloat)

        var font: Font {
            switch self {
            case .hero:       return Typography.hero
            case .display:    return Typography.display
            case .title1:     return Typography.title1
            case .title2:     return Typography.title2
            case .title3:     return Typography.title3
            case .body:       return Typography.body
            case .callout:    return Typography.callout
            case .foot:       return Typography.foot
            case .cap:        return Typography.cap
            case .micro:      return Typography.micro
            case .microSm:    return Typography.microSm
            case .num(let s): return Typography.num(size: s)
            }
        }

        var tracking: CGFloat {
            switch self {
            case .hero:       return -1.6
            case .display:    return -1.1
            case .title1:     return -0.6
            case .title2:     return -0.4
            case .title3:     return -0.2
            case .body:       return -0.1
            case .callout:    return -0.1
            case .foot:       return 0
            case .cap:        return 0.2
            case .micro:      return 1.2
            case .microSm:    return 1.4
            case .num:        return -1
            }
        }

        var isUppercase: Bool {
            switch self {
            case .micro, .microSm: return true
            default:               return false
            }
        }
    }
}

// MARK: - TextStyle ViewModifier

struct StyledText: ViewModifier {
    let style: DS.TextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .textCase(style.isUppercase ? .uppercase : nil)
    }
}

extension View {
    func style(_ style: DS.TextStyle) -> some View {
        modifier(StyledText(style: style))
    }
}

// MARK: - Spacing

extension DS {
    enum Spacing {
        static let s0: CGFloat = 0
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s20: CGFloat = 20
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32
        static let s40: CGFloat = 40
        static let s48: CGFloat = 48
        static let s64: CGFloat = 64
        static let s80: CGFloat = 80
        static let s96: CGFloat = 96
    }
}

// MARK: - Radius

extension DS {
    enum Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }
}

// MARK: - Elevation ViewModifiers

struct PillLightElevation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.30), radius: 4, y: 2)
            .shadow(color: .black.opacity(0.32), radius: 24, y: 10)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
    }
}

struct FloatingElevation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.34), radius: 6, y: 2)
            .shadow(color: .black.opacity(0.42), radius: 48, y: 22)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
    }
}

struct CardElevation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
    }
}

struct RaisedElevation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.34), radius: 2, y: 1)
            .shadow(color: .black.opacity(0.22), radius: 28, y: 12)
    }
}

extension View {
    func pillLightElevation() -> some View {
        modifier(PillLightElevation())
    }

    func floatingElevation() -> some View {
        modifier(FloatingElevation())
    }

    func cardElevation() -> some View {
        modifier(CardElevation())
    }

    func raisedElevation() -> some View {
        modifier(RaisedElevation())
    }
}

// MARK: - Motion

extension DS {
    enum Motion {
        static let fastDuration: TimeInterval = 0.14
        static let baseDuration: TimeInterval = 0.22
        static let slowDuration: TimeInterval = 0.36
        static let standardSpring: Animation = .spring(response: 0.4, dampingFraction: 0.8)
        static let celebrationSpring: Animation = .spring(response: 0.5, dampingFraction: 0.6)
    }
}
