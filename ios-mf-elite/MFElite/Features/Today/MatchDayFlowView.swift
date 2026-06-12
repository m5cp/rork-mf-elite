//
//  MatchDayFlowView.swift
//  MFElite
//
//  "Match Day" — a pre-game routine assembled from existing content. Owns its own
//  three-stage flow: a short intro, the standard session player running the
//  assembled queue, and a custom "You're ready" finish showing the player's card
//  plus one personal cue line. No new per-drill player UI is introduced.
//

import SwiftUI
import SwiftData

struct MatchDayFlowView: View {
    /// The four-item routine, assembled by the Today view from existing content.
    let items: [DrillContext]
    /// A personal pre-match cue line resolved from recent Technical ratings.
    let cueLine: String

    @Environment(\.dismiss) private var dismiss
    @State private var stage: Stage = .intro
    @State private var queue: TrainingQueue?

    private enum Stage { case intro, training, ready }

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            switch stage {
            case .intro:
                MatchDayIntroView(
                    drillCount: items.count,
                    onStart: start,
                    onClose: { dismiss() }
                )
                .transition(.opacity)
            case .training:
                if let queue {
                    SessionPlayerView(queue: queue) {
                        withAnimation(DS.Motion.standardSpring) { stage = .ready }
                    }
                    .transition(.opacity)
                }
            case .ready:
                MatchDayReadyView(cueLine: cueLine) { dismiss() }
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func start() {
        guard !items.isEmpty else { dismiss(); return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        queue = TrainingQueue(items: items, source: .workout, sourceName: "Match Day")
        withAnimation(DS.Motion.standardSpring) { stage = .training }
    }
}

// MARK: - Intro

private struct MatchDayIntroView: View {
    let drillCount: Int
    var onStart: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .frame(width: 36, height: 36)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s16)

            Spacer()

            Image(systemName: "soccerball.inverse")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(DS.Colors.Ink.primary)

            Eyebrow(text: "Match Day Routine")
                .padding(.top, DS.Spacing.s24)

            Text("Get ready.")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s8)

            Text("~10 minutes · activate, visualize, lock in")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, DS.Spacing.s12)
                .padding(.horizontal, DS.Spacing.s32)

            stepsList
                .padding(.top, DS.Spacing.s32)
                .padding(.horizontal, DS.Spacing.s20)

            Spacer()

            PrimaryButton(label: "Start") { onStart() }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s24)
        }
    }

    private var stepsList: some View {
        VStack(spacing: DS.Spacing.s12) {
            stepRow(icon: "figure.run", title: "Activate", detail: "Two quick physical primers")
            stepRow(icon: "eye", title: "Visualize", detail: "See the game before you play it")
            stepRow(icon: "bolt.heart", title: "Lock in", detail: "Self-talk to set your mindset")
        }
    }

    private func stepRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: DS.Spacing.s16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(width: 44, height: 44)
                .background(DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(detail)
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.s12)
        .frame(maxWidth: .infinity)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
    }
}

// MARK: - Finish ("You're ready")

private struct MatchDayReadyView: View {
    let cueLine: String
    var onDone: () -> Void

    @Query private var players: [PlayerState]
    @State private var reveal = false

    private var profile = PlayerProfileStore.shared
    private var cardStore = PlayerCardStore.shared

    init(cueLine: String, onDone: @escaping () -> Void) {
        self.cueLine = cueLine
        self.onDone = onDone
    }

    private var info: CardPlayerInfo {
        let xp = players.first?.xp ?? 0
        let rank = AcademyRank.unlockedRank(for: xp, hasFullAccess: SubscriptionService.shared.hasFullAccess)
        return CardPlayerInfo(
            name: profile.displayName,
            rankNumeral: rank.numeral,
            rankTitle: rank.title,
            xp: xp,
            streak: players.first?.streak ?? 0,
            position: profile.position,
            positionCode: profile.positionCode,
            kitNumber: profile.kitNumber,
            foot: profile.foot,
            classYearText: profile.classYearText,
            academy: "MF Elite",
            initials: profile.initials,
            avatar: profile.avatar
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Eyebrow(text: "Match Day")
                    .padding(.top, DS.Spacing.s64)

                Text("YOU'RE READY")
                    .style(.hero)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s8)

                GeometryReader { geo in
                    PlayerCardCanvas(
                        design: cardStore.design,
                        photo: profile.avatarPhoto,
                        player: info,
                        width: geo.size.width
                    )
                    .raisedElevation()
                }
                .aspectRatio(1 / cardAspect, contentMode: .fit)
                .padding(.horizontal, DS.Spacing.s32)
                .padding(.top, DS.Spacing.s32)
                .scaleEffect(reveal ? 1 : 0.92)
                .opacity(reveal ? 1 : 0)

                cueCard
                    .padding(.top, DS.Spacing.s24)
                    .padding(.horizontal, DS.Spacing.s20)

                PrimaryButton(label: "Done") { onDone() }
                    .padding(.top, DS.Spacing.s32)
                    .padding(.horizontal, DS.Spacing.s20)
            }
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Colors.Bg.base)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(DS.Motion.celebrationSpring) { reveal = true }
        }
    }

    private var cueCard: some View {
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: "quote.opening")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(cueLine)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cueLine)
    }
}
