//
//  ShareCardComposite.swift
//  MFElite
//
//  The full card + its editable overlays (stickers, caption) composited at the
//  design resolution. Used for export (`renderScale == 1`) and as the visual
//  base for the interactive editor preview (`renderScale == fit-scale`). The
//  same sticker / caption content views back both so what a player edits is
//  exactly what ships.
//

import SwiftUI

// MARK: - Sticker content

/// The visual for a single sticker, sized in design px times `renderScale`.
struct ShareStickerContent: View {
    let sticker: EditorSticker
    let renderScale: CGFloat

    var body: some View {
        let s = sticker.scale * renderScale
        Group {
            switch sticker.kind {
            case let .text(label):
                Text(label.uppercased())
                    .font(ShareFont.display(EditorSticker.textBase * s))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 38 * s)
                    .padding(.top, 16 * s)
                    .padding(.bottom, 10 * s)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8 * s))
                    .shadow(color: .black.opacity(0.35), radius: 18 * s, y: 8 * s)
            case let .image(asset):
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: EditorSticker.imageBase * s, height: EditorSticker.imageBase * s)
                    .shadow(color: .black.opacity(0.35), radius: 18 * s, y: 8 * s)
            }
        }
        .rotationEffect(.degrees(sticker.rotation))
    }
}

// MARK: - Caption content

/// The draggable caption chip, sized in design px times `renderScale`.
struct ShareCaptionContent: View {
    let text: String
    let theme: ShareTheme
    let renderScale: CGFloat

    var body: some View {
        let s = renderScale
        Text(text.uppercased())
            .font(ShareFont.display(64 * s))
            .foregroundStyle(theme.chipInk)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 44 * s)
            .padding(.top, 18 * s)
            .padding(.bottom, 12 * s)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 10 * s))
            .rotationEffect(.degrees(-3))
            .shadow(color: .black.opacity(0.45), radius: 60 * s, y: 20 * s)
    }
}

// MARK: - Composite (export)

/// The complete card with its overlays, laid out at full design size. Rendered
/// through `ShareCardRenderer` for export; also mirrors what the editor shows.
struct ShareCardComposite: View {
    let moment: ShareMoment
    let theme: ShareTheme
    let format: ShareFormat
    let backdrop: ShareBackdrop
    let show: ShareShow
    let caption: EditorCaption?
    let stickers: [EditorSticker]
    var photoAllowed: Bool = false
    var photo: UIImage? = nil

    var body: some View {
        ZStack {
            MFShareCardV2(
                moment: moment, theme: theme, format: format,
                backdrop: backdrop, show: show,
                photoAllowed: photoAllowed, photo: photo
            )

            ForEach(stickers) { sticker in
                ShareStickerContent(sticker: sticker, renderScale: 1)
                    .position(x: sticker.x * format.width, y: sticker.y * format.height)
            }

            if let caption {
                ShareCaptionContent(text: caption.text, theme: theme, renderScale: 1)
                    .frame(maxWidth: format.width * 0.9)
                    .position(x: caption.x * format.width, y: caption.y * format.height)
            }
        }
        .frame(width: format.width, height: format.height)
        .clipped()
    }
}
