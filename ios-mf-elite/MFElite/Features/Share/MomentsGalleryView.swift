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
    @Query private var progress: [DrillProgress]
    @Query private var combineResults: [CombineResult]
    @Query(sort: \CombineTest.sortIndex) private var combineTests: [CombineTest]
    @Query private var sessions: [SessionLogEntry]

    @State private var preview: ShareMoment?
    @State private var pickerKind: ShareMomentKind?

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
            ShareEditorView(moment: moment)
        }
        .sheet(item: $pickerKind) { kind in
            CombineCardPickerSheet(kind: kind) { built in
                preview = built
            }
            .presentationDetents([.medium, .large])
        }
        .task { await WeeklyHealthStats.shared.refresh() }
        .onAppear {
            if let initialKind, preview == nil {
                preview = moment(for: initialKind)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            HStack(spacing: DS.Spacing.s8) {
                Rectangle()
                    .fill(DS.Colors.Gold.base)
                    .frame(width: 22, height: 2)
                Text("MF ELITE · MOMENTS")
                    .style(.micro)
                    .tracking(2.4)
                    .foregroundStyle(DS.Colors.Gold.textLight)
            }

            Text("SHARE YOUR GRIND")
                .font(ShareFont.display(38))
                .foregroundStyle(DS.Colors.Ink.primary)

            Text("Turn any accomplishment into a card built for Instagram. Every card carries a scannable code to the app.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("+5 XP per platform when you share your Player Card or Rep The Badge — first share on each app, every day.", systemImage: "bolt.fill")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(DS.Colors.Gold.textLight)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.Gold.faint, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .padding(.top, DS.Spacing.s4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - Grid

    private func isEarned(_ kind: ShareMomentKind) -> Bool {
        ShareMomentBuilder.isEarned(
            kind,
            players: players,
            progress: progress,
            combineResults: combineResults,
            combineTests: combineTests
        )
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ShareMomentKind.allCases) { kind in
                let unlocked = isEarned(kind)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if kind == .combineResult || kind == .combineScorecard {
                        pickerKind = kind
                    } else {
                        preview = moment(for: kind)
                    }
                } label: {
                    tile(kind, locked: !unlocked)
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!unlocked)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    private func tile(_ kind: ShareMomentKind, locked: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            ZStack(alignment: .topTrailing) {
                Image(kind.tileAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .offset(x: 10, y: -4)
                }
            }

            Text(kind.label)
                .style(.foot)
                .fontWeight(.bold)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(locked ? unlockHint(kind) : "CREATE CARD ›")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(locked ? DS.Colors.Ink.tertiary : Color(hex: "E8B84B"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
        .opacity(locked ? 0.55 : 1)
    }

    /// Short hint telling the player how to unlock a locked card.
    private func unlockHint(_ kind: ShareMomentKind) -> String {
        switch kind {
        case .streak: return "START A STREAK"
        case .badge: return "EARN A BADGE"
        case .combineResult: return "DO A COMBINE TEST"
        case .combineScorecard: return "FINISH THE COMBINE"
        case .levelMastered: return "MASTER A LEVEL"
        default: return "LOCKED"
        }
    }

    // MARK: - Moment resolution

    private func moment(for kind: ShareMomentKind) -> ShareMoment {
        ShareMomentBuilder.galleryMoment(
            kind,
            players: players,
            progress: progress,
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
