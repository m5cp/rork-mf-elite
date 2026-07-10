//
//  SharePreviewView.swift
//  MFElite
//
//  A simple, full-screen preview of a share card for a single moment. This is
//  the Phase 2 destination — it renders the Phase 1 `MFShareCardV2`, lets the
//  player switch export format, and shares the rendered image via the native
//  share sheet. The full editor (themes, stickers, captions) lands in Phase 3.
//

import SwiftUI

struct SharePreviewView: View {
    let moment: ShareMoment
    /// Starting theme for the preview. Defaults to Elite Gold.
    var theme: ShareTheme = .gold

    @Environment(\.dismiss) private var dismiss
    @State private var formatID: String = ShareFormat.story.id
    @State private var backdrop: ShareBackdrop = .glow
    @State private var exported: ShareableImage?
    @State private var isExporting = false

    private var format: ShareFormat { ShareFormat.format(id: formatID) }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.Bg.base.ignoresSafeArea()

                VStack(spacing: DS.Spacing.s20) {
                    formatPicker

                    GeometryReader { geo in
                        let scale = min(
                            geo.size.width / format.width,
                            geo.size.height / format.height
                        )
                        card
                            .scaleEffect(scale, anchor: .center)
                            .frame(width: format.width * scale, height: format.height * scale)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }

                    shareButton
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s12)
                .padding(.bottom, DS.Spacing.s24)
            }
            .navigationTitle(moment.kind.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .preferredColorScheme(.dark)
            .sheet(item: $exported) { item in
                ShareSheet(items: [item.image])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Card

    private var card: some View {
        MFShareCardV2(moment: moment, theme: theme, format: format, backdrop: backdrop)
    }

    // MARK: - Format picker

    private var formatPicker: some View {
        Picker("Format", selection: $formatID) {
            ForEach(ShareFormat.all) { f in
                Text("\(f.name) \(f.ratio)").tag(f.id)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Share

    private var shareButton: some View {
        PrimaryButton(label: isExporting ? "Preparing…" : "Share card") {
            exportAndShare()
        }
    }

    private func exportAndShare() {
        guard !isExporting else { return }
        isExporting = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let image = ShareCardRenderer.renderCard(card, format: format)
        isExporting = false
        if let image { exported = ShareableImage(image: image) }
    }
}

#Preview {
    SharePreviewView(moment: .sample(.streak))
}
