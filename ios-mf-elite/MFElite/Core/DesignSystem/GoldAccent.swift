//
// GoldAccent.swift
// MFElite
//
// ── ELITE GOLD ACCENT SYSTEM ──
// Drop this file into Core/DesignSystem/ — no other dependencies.
// The app stays black & white; gold appears ONLY on:
// 1. symbols & icons → DS.Colors.Gold.base
// 2. hero-card frame edges → .goldEdge(cornerRadius:)
// 3. avatar/monogram rings → .goldRing(...) / gold border colors
// 4. progress fills → Gold.progressGradient
//
// READABILITY RULES (non-negotiable):
// • Small gold TYPE always uses Gold.textLight (#F6D98A) at FULL opacity.
// Never render text in a dimmed/alpha version of #E8B84B — it goes muddy.
// • Gold text only at micro/eyebrow scale or tag chips. Body, titles and
// numerals stay white.
// • Never gold-on-gold. Solid-gold chips use dark ink Gold.inkOnGold.
//

import SwiftUI

// MARK: - Tokens

extension DS.Colors {
 enum Gold {
 /// Primary accent — icon strokes, fills, chips, active tab.
 static let base = Color(hex: "#E8B84B")
 /// Light gold — small TEXT and gradient highlights. Full opacity only.
 static let textLight = Color(hex: "#F6D98A")
 /// Hairline borders, chevrons, completed rails.
 static let line = Color(hex: "#E8B84B").opacity(0.50)
 /// Tinted fills (active lens backgrounds).
 static let soft = Color(hex: "#E8B84B").opacity(0.14)
 /// Ambient glow / halo.
 static let faint = Color(hex: "#E8B84B").opacity(0.07)
 /// Dark ink for text sitting ON a solid gold fill.
 static let inkOnGold = Color(hex: "#141005")

 /// Progress bars & pips: gold → light gold, left to right.
 static let progressGradient = LinearGradient(
 colors: [base, textLight],
 startPoint: .leading,
 endPoint: .trailing
 )

 /// Metallic frame-edge gradient (140° ≈ topLeading → bottomTrailing).
 static let edgeGradient = LinearGradient(
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
}

// MARK: - Gold edge (hero cards) — the signature move
//
// 1px metallic gradient border + 3D lift:
// tight contact shadow, deep ambient shadow, faint gold halo,
// and an inner bevel (light catches the top edge, base sits in shadow).
// Use SPARINGLY — one, max two per screen (hero card + one standing strip).
// Regular cards keep the plain hairline Card.

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
 // 3D lift: contact + ambient + gold halo
 .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
 .shadow(color: .black.opacity(0.58), radius: 28, y: 24)
 .shadow(color: DS.Colors.Gold.faint, radius: 20)
 }
}

extension View {
 /// Wrap a hero card in the gold metallic frame with 3D lift.
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
 .overlay(shape.stroke(DS.Colors.Gold.base.opacity(0.90), lineWidth: 1))
 .shadow(color: .black.opacity(0.55), radius: 5, y: 4)
 .shadow(color: DS.Colors.Gold.base.opacity(0.22), radius: 7)
 }
}

extension View {
 /// Gold avatar ring: outer gold line, black gap, inner light-gold echo, soft lift + glow.
 func goldRing(shape: AnyShape = AnyShape(Circle())) -> some View {
 modifier(GoldRing(shape: shape))
 }
}

// MARK: - Preview

#Preview("Gold accent kit") {
 ZStack {
 DS.Colors.Bg.base.ignoresSafeArea()
 VStack(spacing: 28) {
 // Hero card with gold edge
 VStack(alignment: .leading, spacing: 8) {
 Text("SESSION · STRIKER")
 .style(.micro)
 .foregroundStyle(DS.Colors.Gold.textLight)
 Text("First touch under pressure")
 .style(.title2)
 .foregroundStyle(.white)
 }
 .padding(20)
 .frame(maxWidth: .infinity, alignment: .leading)
 .goldEdge(cornerRadius: 26)

 // Avatar ring
 Avatar(size: 56).goldRing()

 // Progress fill
 GeometryReader { geo in
 ZStack(alignment: .leading) {
 Capsule().fill(DS.Colors.Line.subtle)
 Capsule()
 .fill(DS.Colors.Gold.progressGradient)
 .frame(width: geo.size.width * 0.62)
 .shadow(color: DS.Colors.Gold.base.opacity(0.35), radius: 4)
 }
 }
 .frame(height: 4)

 // Icon + tag
 HStack(spacing: 14) {
 DisciplineMark(kind: "triangle", color: DS.Colors.Gold.base)
 Text("ELITE")
 .style(.micro)
 .foregroundStyle(DS.Colors.Gold.base)
 .padding(.vertical, 4).padding(.horizontal, 8)
 .overlay(RoundedRectangle(cornerRadius: 4).stroke(DS.Colors.Gold.line, lineWidth: 1))
 }
 }
 .padding(.horizontal, 24)
 }
}
