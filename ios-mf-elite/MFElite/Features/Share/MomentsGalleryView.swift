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
    /// Explanation shown when a locked tile is tapped.
    @State private var lockedHint: LockedHint?

    /// Identifiable so it can drive a transient toast.
    private struct LockedHint: Identifiable, Equatable {
        let kind: ShareMomentKind
        let text: String
        var id: String { kind.rawValue }
    }

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.s12),
        GridItem(.flexible(), spacing: DS.Spacing.s12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                grid
            }
            .padding(.bottom, DS.tabBarClearance + DS.Spacing.s24)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { lockedToast }
        .fullScreenCover(item: $preview) { moment in
            ShareEditorView(moment: moment)
        }
        .sheet(item: $pickerKind) { kind in
            CombineCardPickerSheet(kind: kind) { built in
                preview = built
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: lockedHint) { _, hint in
            guard hint != nil else { return }
            // Auto-dismiss; tapping another locked tile replaces it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(DS.Motion.standardSpring) {
                    if lockedHint == hint { lockedHint = nil }
                }
            }
        }
        .task { await WeeklyHealthStats.shared.refresh() }
        .onAppear {
            if let initialKind, preview == nil {
                preview = moment(for: initialKind)
            }
        }
    }

    // MARK: - Header

    /// Header lockup.
    ///
    /// The previous version stacked four separate accent objects — a tick rule,
    /// an accent eyebrow, an accent XP pill and an accent CTA on every tile —
    /// around a flat white headline. Everything around the title was shouting
    /// and the title itself had no idea in it, which is what made it read as
    /// generic.
    ///
    /// This is a weight-stack: size contrast carries the emphasis, and the
    /// accent appears exactly once, as a rule, never as a coloured word. That
    /// also means it holds up across all five accents instead of being tuned
    /// for gold.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SHARE")
                .font(ShareFont.displayScaled(24, relativeTo: .title3))
                .tracking(8)
                .foregroundStyle(DS.Colors.Ink.quaternary)

            Text("YOUR GRIND")
                .font(ShareFont.displayScaled(52))
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, -2)

            RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                .fill(DS.Colors.Gold.base)
                .frame(width: 64, height: 3)
                .padding(.top, DS.Spacing.s12)

            Text("Turn any accomplishment into a card built for Instagram. Every card carries a scannable code to the app.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.Spacing.s16)

            ShareXPBanner()
                .padding(.top, DS.Spacing.s12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Share your grind. Turn any accomplishment into a card built for Instagram.")
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
        LazyVGrid(columns: columns, spacing: DS.Spacing.s12) {
            ForEach(ShareMomentKind.allCases) { kind in
                let unlocked = isEarned(kind)
                Button {
                    guard unlocked else {
                        // Locked tiles used to be `.disabled`, so tapping one
                        // did nothing — no haptic, no explanation. Now it says
                        // how to unlock it.
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        withAnimation(DS.Motion.standardSpring) {
                            lockedHint = LockedHint(kind: kind, text: unlockHint(kind))
                        }
                        return
                    }
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
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    unlocked
                        ? "\(kind.label). Create card."
                        : "\(kind.label). Locked. \(unlockHint(kind))"
                )
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
                    .opacity(locked ? 0.45 : 1)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .offset(x: 10, y: -4)
                        .accessibilityHidden(true)
                }
            }

            Text(kind.label)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: DS.Spacing.s4) {
                Text(locked ? unlockHint(kind) : "CREATE CARD")
                    .style(.micro)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !locked {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            // Was Ink.tertiary under a 0.55 tile opacity — about 40% white on
            // #121212, ~3.7:1, which fails WCAG AA for text under 18pt. The
            // tile no longer dims its own text layer.
            .foregroundStyle(locked ? DS.Colors.Ink.secondary : DS.Colors.Gold.textLight)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(.horizontal, DS.Spacing.s12)
        .padding(.vertical, DS.Spacing.s16)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
    }

    /// Toast explaining why a locked card can't be opened yet.
    @ViewBuilder
    private var lockedToast: some View {
        if let lockedHint {
            HStack(spacing: DS.Spacing.s8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.Colors.Gold.textLight)
                Text(lockedHint.text)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.s16)
            .padding(.vertical, DS.Spacing.s12)
            .background(DS.Colors.Bg.raised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(DS.Colors.Gold.line, lineWidth: 1)
            )
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.tabBarClearance + DS.Spacing.s12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.isStaticText)
            // This toast sits in the same band as the floating search button.
            // Attached here rather than on the screen so search only steps
            // aside for the couple of seconds the hint is actually up.
            .suppressesFloatingSearch()
        }
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
