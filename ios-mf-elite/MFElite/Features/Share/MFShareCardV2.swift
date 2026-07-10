//
//  MFShareCardV2.swift
//  MFElite
//
//  Full-bleed, export-ready share cards. One card view drives all nine moment
//  types across the five themes, four backdrops, and three formats. Everything is
//  laid out in design px at a 1080-wide resolution and rendered through
//  `ShareCardRenderer`. The body auto-fits above the footer (scales down
//  uniformly, never clips the footer).
//

import SwiftUI

// MARK: - Card

struct MFShareCardV2: View {
    let moment: ShareMoment
    let theme: ShareTheme
    let format: ShareFormat
    var backdrop: ShareBackdrop = .solid
    var show: ShareShow = ShareShow()
    /// Parent permission for photo backdrops (render support only in this phase).
    var photoAllowed: Bool = false
    /// The user photo used by the `.photo` backdrop, when allowed.
    var photo: UIImage? = nil

    var body: some View {
        ZStack {
            ShareBackdropView(theme: theme, backdrop: backdrop, photo: photo, photoAllowed: photoAllowed)

            VStack(spacing: 0) {
                AutoFitBody(naturalHeight: moment.naturalHeight, gap: format.bodyGap) {
                    ShareMomentBody(moment: moment, theme: theme, show: show)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                ShareFooterStrip(theme: theme)
            }
        }
        .frame(width: format.width, height: format.height)
        .background(theme.bg)
        .clipped()
    }
}

// MARK: - Auto-fit

/// Scales the moment body down uniformly so it always fits the space above the
/// footer, leaving ~100px of breathing room. Pure layout math (no state) so it
/// resolves correctly inside `ImageRenderer`, which renders in a single pass.
private struct AutoFitBody<Content: View>: View {
    let naturalHeight: CGFloat
    let gap: CGFloat
    @ViewBuilder let content: () -> Content

    /// Content width budget: 1080 minus the 60px side padding on each edge.
    private let contentWidth: CGFloat = 960
    private let breathingRoom: CGFloat = 100

    var body: some View {
        GeometryReader { geo in
            let available = max(1, geo.size.height - breathingRoom)
            let scale = min(1, available / naturalHeight)
            VStack(spacing: gap) {
                content()
            }
            .frame(width: contentWidth)
            .fixedSize(horizontal: false, vertical: true)
            .scaleEffect(scale)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Backdrop

struct ShareBackdropView: View {
    let theme: ShareTheme
    let backdrop: ShareBackdrop
    var photo: UIImage? = nil
    var photoAllowed: Bool = false

    var body: some View {
        switch backdrop {
        case .solid:
            theme.bg
        case .glow:
            ZStack {
                theme.bg
                RadialGradient(
                    colors: [theme.accent.opacity(0.33), theme.bg.opacity(0)],
                    center: UnitPoint(x: 0.5, y: -0.1),
                    startRadius: 0,
                    endRadius: 1200
                )
            }
        case .pitch:
            PitchTexture(theme: theme)
        case .photo:
            PhotoBackdrop(theme: theme, photo: photo, photoAllowed: photoAllowed)
        }
    }
}

/// Solid bg + faint horizontal stripes, center circle and halfway line.
private struct PitchTexture: View {
    let theme: ShareTheme

    var body: some View {
        GeometryReader { geo in
            let lineColor = theme.ink.opacity(0.03)
            let strongLine = theme.ink.opacity(0.08)
            ZStack {
                theme.bg
                // Horizontal stripes every 160px.
                VStack(spacing: 160) {
                    ForEach(0..<Int(geo.size.height / 160) + 1, id: \.self) { _ in
                        Rectangle()
                            .fill(lineColor)
                            .frame(height: 80)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                // Halfway line.
                Rectangle()
                    .fill(strongLine)
                    .frame(height: 3)
                // Center circle.
                Circle()
                    .stroke(strongLine, lineWidth: 3)
                    .frame(width: 720, height: 720)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// The photo backdrop. Render support only in this phase — no picker or gate.
private struct PhotoBackdrop: View {
    let theme: ShareTheme
    let photo: UIImage?
    let photoAllowed: Bool

    var body: some View {
        if !photoAllowed {
            ZStack {
                theme.bg
                Text("PHOTO LOCKED\nask a parent to enable")
                    .font(.system(size: 30, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .lineSpacing(12)
                    .foregroundStyle(theme.sub)
            }
        } else {
            ZStack {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    theme.neutralFill(0.14)
                }
                // Bottom scrim so type stays legible.
                LinearGradient(
                    colors: [theme.bg.opacity(0), theme.bg],
                    startPoint: UnitPoint(x: 0.5, y: 0.3),
                    endPoint: UnitPoint(x: 0.5, y: 0.92)
                )
            }
        }
    }
}
