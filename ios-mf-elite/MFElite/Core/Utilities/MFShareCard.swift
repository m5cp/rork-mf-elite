//
//  MFShareCard.swift
//  MFElite
//
//  Reusable, branded share-card chrome for ImageRenderer exports: a black
//  background, the MF logo, generous padding and an "MF Elite" footer wordmark.
//  All colors are explicit (never semantic) because ImageRenderer renders in a
//  fixed light environment — semantic colors would not adapt as intended.
//

import SwiftUI

/// Wrapper so a plain `String` can drive a SwiftUI `.sheet(item:)`.
struct ShareableText: Identifiable {
    let id = UUID()
    let text: String
}

/// Small shared helpers for the sharing layer.
enum ShareText {
    /// First name only — used everywhere a share must not expose a surname.
    static func firstName(_ fullName: String) -> String {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        return first.isEmpty ? "Player" : first
    }
}

/// A dark, branded container for shareable images. Wraps arbitrary content with
/// the MF logo on top and an "MF Elite" wordmark footer.
struct MFShareCard<Content: View>: View {
    var eyebrow: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 24) {
            Image("mf-logo-white")
                .resizable()
                .scaledToFit()
                .frame(height: 26)

            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.45))
            }

            content()

            Text("MF ELITE")
                .font(.system(size: 12, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

/// Renders any view to a crisp shareable `UIImage` at a fixed share width.
@MainActor
enum ShareCardRenderer {
    static func render<V: View>(_ view: V, width: CGFloat = 360) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: width))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Renders a share card that is already laid out at its full design size (the
    /// V2 cards are built at 1080-wide, so `scale = 1` yields the exact export
    /// pixel size — e.g. 1080×1920 for a Story). Pass the desired export format.
    static func renderCard<V: View>(_ view: V, format: ShareFormat) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: format.width, height: format.height))
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
