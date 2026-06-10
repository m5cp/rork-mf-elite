//
//  PlayerCardView.swift
//  MFElite
//
//  Full-screen showcase of the player's shareable card. Renders the live design,
//  offers an Edit entry into the Instagram-style editor, and exports / shares a
//  high-resolution image.
//

import SwiftUI
import SwiftData

struct PlayerCardRoute: Hashable {}

struct PlayerCardView: View {
    @Query private var players: [PlayerState]

    private var profile = PlayerProfileStore.shared
    private var cardStore = PlayerCardStore.shared

    @State private var showEditor = false
    @State private var shareImage: ShareableImage?
    @State private var isExporting = false

    private var info: CardPlayerInfo {
        let xp = players.first?.xp ?? 0
        let rank = AcademyRank.rank(for: xp)
        return CardPlayerInfo(
            name: profile.displayName,
            rankNumeral: rank.numeral,
            rankTitle: rank.title,
            xp: xp,
            streak: players.first?.streak ?? 0,
            position: profile.position,
            kitNumber: profile.kitNumber,
            initials: profile.initials
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.s24) {
                GeometryReader { geo in
                    PlayerCardCanvas(
                        design: cardStore.design,
                        photo: cardStore.backgroundPhoto,
                        player: info,
                        width: geo.size.width
                    )
                    .raisedElevation()
                }
                .aspectRatio(1 / cardAspect, contentMode: .fit)
                .padding(.top, DS.Spacing.s8)

                actions
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("Player Card")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showEditor) {
            PlayerCardEditorView(player: info)
        }
        .sheet(item: $shareImage) { item in
            ShareSheet(items: [item.image])
                .presentationDetents([.medium, .large])
        }
    }

    private var actions: some View {
        VStack(spacing: DS.Spacing.s12) {
            PrimaryButton(label: isExporting ? "Preparing…" : "Share Card") {
                share()
            }

            SecondaryButton(label: "Edit Card") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showEditor = true
            }

            Text("Add a photo, text, colors and drawings — then share to your story or save to Photos.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .multilineTextAlignment(.center)
                .padding(.top, DS.Spacing.s4)
                .padding(.horizontal, DS.Spacing.s16)
        }
    }

    private func share() {
        guard !isExporting else { return }
        isExporting = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let image = CardExporter.render(
            design: cardStore.design,
            photo: cardStore.backgroundPhoto,
            player: info
        )
        isExporting = false
        if let image {
            shareImage = ShareableImage(image: image)
        }
    }
}

/// Wrapper so a UIImage can drive a SwiftUI `.sheet(item:)`.
struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Renders a `CardDesign` to a crisp, shareable `UIImage` at export resolution.
@MainActor
enum CardExporter {
    static func render(design: CardDesign, photo: UIImage?, player: CardPlayerInfo) -> UIImage? {
        let exportWidth: CGFloat = 1080
        let canvas = PlayerCardCanvas(
            design: design,
            photo: photo,
            player: player,
            width: exportWidth
        )
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
