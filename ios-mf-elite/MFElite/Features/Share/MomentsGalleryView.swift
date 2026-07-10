//
//  MomentsGalleryView.swift
//  MFElite
//
//  "Share Your Grind" — the entry point that lists every shareable moment as a
//  2-column tile grid. Tapping a tile resolves the player's real data for that
//  moment (falling back to a sample when there's nothing yet) and opens a
//  full-screen card preview. The editor lands in Phase 3.
//

import SwiftUI
import SwiftData

/// Navigation route to the share moments gallery.
struct ShareRoute: Hashable {}

struct MomentsGalleryView: View {
    /// Optional moment to open immediately on appear (deep-link support).
    var initialKind: ShareMomentKind?

    @Query private var players: [PlayerState]
    @Query private var combineResults: [CombineResult]
    @Query(sort: \CombineTest.sortIndex) private var combineTests: [CombineTest]
    @Query private var sessions: [SessionLogEntry]

    @State private var preview: ShareMoment?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                grid
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $preview) { moment in
            SharePreviewView(moment: moment)
        }
        .onAppear {
            if let initialKind, preview == nil {
                preview = moment(for: initialKind)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            (Text("SHARE YOUR ") + Text("GRIND").foregroundColor(Color(hex: "E8B84B")))
                .font(ShareFont.display(38))
                .foregroundStyle(DS.Colors.Ink.primary)

            Text("Turn any accomplishment into a card built for Instagram. Every card carries a scannable code to the app.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ShareMomentKind.allCases) { kind in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    preview = moment(for: kind)
                } label: {
                    tile(kind)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    private func tile(_ kind: ShareMomentKind) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Image(kind.tileAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)

            Text(kind.label)
                .style(.foot)
                .fontWeight(.bold)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("CREATE CARD ›")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color(hex: "E8B84B"))
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
    }

    // MARK: - Moment resolution

    private func moment(for kind: ShareMomentKind) -> ShareMoment {
        ShareMomentBuilder.galleryMoment(
            kind,
            players: players,
            combineResults: combineResults,
            combineTests: combineTests,
            sessions: sessions
        )
    }
}

#Preview {
    NavigationStack {
        MomentsGalleryView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [
        Discipline.self, Category.self, MasteryLevel.self,
        Drill.self, DrillProgress.self, PlayerState.self,
        CombineTest.self, CombineResult.self, SessionLogEntry.self
    ])
}
