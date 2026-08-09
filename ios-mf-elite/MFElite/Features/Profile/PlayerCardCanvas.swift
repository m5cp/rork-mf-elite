//
//  PlayerCardCanvas.swift
//  MFElite
//
//  The visual player card. Renders a fixed 4:5 poster at any width — the same
//  view backs the on-screen preview, the editor base layer, and the
//  high-resolution image export. Everything is sized off the passed `width`
//  so the design scales identically from a 320pt preview to a 1080px export.
//

import SwiftUI

/// Aspect ratio of the card (width : height). 4:5 — an Instagram-friendly poster.
let cardAspect: CGFloat = 1.25

struct PlayerCardCanvas: View {
    let design: CardDesign
    /// The player's portrait, mirrored from the profile avatar.
    let photo: UIImage?
    let player: CardPlayerInfo
    let width: CGFloat
    /// Render the text stickers. Editor turns stickers off to draw its own
    /// interactive layer, but export keeps them on.
    var includeOverlays: Bool = true

    private var height: CGFloat { width * cardAspect }
    private var accent: Color { design.theme.accent }

    var body: some View {
        ZStack {
            background
            slashTexture
            scrim
            memberCard
            strokesLayer
            if includeOverlays { overlayLayer }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.06, style: .continuous))
    }

    // MARK: - The white member card

    private var memberCard: some View {
        MemberCardView(
            player: player,
            avatarPhoto: photo,
            width: width * 0.84,
            accent: accent,
            showStats: design.showStatPlate
        )
        .shadow(color: .black.opacity(0.45), radius: width * 0.05, y: width * 0.02)
        .frame(width: width, height: height)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: design.theme.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Photographic themes lay their backdrop over the matching
            // gradient rather than replacing it, so the card is never blank
            // while the image decodes — and the export renderer, which draws
            // synchronously, always has something underneath.
            if let art = design.theme.imageName {
                Image(art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    // The shared `scrim` below only darkens the lower half of
                    // the card, which is enough for a gradient theme but not
                    // for a photograph — Dawn's sky is nearly white at the
                    // top, and a player can drag a white text sticker there.
                    // This wash is weighted to the top for that reason.
                    .overlay(
                        LinearGradient(
                            colors: [
                                .black.opacity(0.52),
                                .black.opacity(0.26),
                                .black.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    private var slashTexture: some View {
        Canvas { context, size in
            let spacing = size.width / 7
            for i in 0..<10 {
                let offset = CGFloat(i) * spacing
                var path = Path()
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                context.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 1.5)
            }
        }
        .allowsHitTesting(false)
    }

    private var scrim: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.15), .black.opacity(0.85)],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    // MARK: - Strokes (free-hand pen)

    private var strokesLayer: some View {
        Canvas { context, size in
            for stroke in design.strokes {
                guard stroke.points.count > 1 else { continue }
                var path = Path()
                let first = stroke.points[0]
                path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                for p in stroke.points.dropFirst() {
                    path.addLine(to: CGPoint(x: p.x * size.width, y: p.y * size.height))
                }
                context.stroke(
                    path,
                    with: .color(Color(hex: stroke.colorHex)),
                    style: StrokeStyle(
                        lineWidth: stroke.widthFraction * size.width,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Legacy stat plate (unused; member card replaces it)

    private var legacyStatPlate: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top brand row
            HStack {
                Text("MF ELITE")
                    .font(.system(size: width * 0.035, weight: .heavy, design: .monospaced))
                    .tracking(width * 0.01)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("PLAYER CARD")
                    .font(.system(size: width * 0.028, weight: .medium, design: .monospaced))
                    .tracking(width * 0.008)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 0)

            // Rank pill
            HStack(spacing: width * 0.02) {
                Text("RANK \(player.rankNumeral)")
                    .font(.system(size: width * 0.03, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, width * 0.03)
                    .padding(.vertical, width * 0.018)
                    .background(accent)
                    .clipShape(Capsule())
                Text(player.rankTitle.uppercased())
                    .font(.system(size: width * 0.03, weight: .bold, design: .monospaced))
                    .tracking(width * 0.006)
                    .foregroundStyle(.white.opacity(0.8))
            }

            // Name
            Text(player.name)
                .font(.system(size: width * 0.13, weight: .heavy))
                .tracking(-width * 0.004)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .padding(.top, width * 0.025)

            // Accent underline
            Rectangle()
                .fill(accent)
                .frame(width: width * 0.18, height: width * 0.012)
                .padding(.top, width * 0.02)

            // Position / kit
            if !player.position.isEmpty || !player.kitNumber.isEmpty {
                HStack(spacing: width * 0.025) {
                    if !player.position.isEmpty {
                        Text(player.position.uppercased())
                            .font(.system(size: width * 0.032, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    if !player.kitNumber.isEmpty {
                        Text("#\(player.kitNumber)")
                            .font(.system(size: width * 0.032, weight: .semibold, design: .monospaced))
                            .foregroundStyle(accent)
                    }
                }
                .padding(.top, width * 0.025)
            }

            // Stat row
            HStack(spacing: 0) {
                statCell(value: player.xp.formatted(), label: "XP")
                divider
                statCell(value: "\(player.streak)", label: "DAY STREAK")
                divider
                statCell(value: player.rankNumeral, label: "RANK")
            }
            .padding(.top, width * 0.05)
        }
        .padding(width * 0.06)
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: width * 0.008) {
            Text(value)
                .font(.system(size: width * 0.07, weight: .heavy).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: width * 0.023, weight: .medium, design: .monospaced))
                .tracking(width * 0.004)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: 1, height: width * 0.09)
    }

    // MARK: - Text stickers (non-interactive render for export)

    private var overlayLayer: some View {
        ZStack {
            ForEach(design.overlays) { overlay in
                CardTextLabel(overlay: overlay, cardWidth: width)
                    .position(x: overlay.x * width, y: overlay.y * height)
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

/// Shared text-sticker rendering so the editor and the export look identical.
struct CardTextLabel: View {
    let overlay: CardTextOverlay
    let cardWidth: CGFloat

    var body: some View {
        Text(overlay.text)
            .font(.system(size: overlay.sizeFraction * cardWidth, weight: overlay.isBold ? .heavy : .semibold))
            .foregroundStyle(Color(hex: overlay.colorHex))
            .shadow(color: .black.opacity(0.35), radius: cardWidth * 0.01, y: 1)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .rotationEffect(.radians(overlay.rotation))
    }
}
