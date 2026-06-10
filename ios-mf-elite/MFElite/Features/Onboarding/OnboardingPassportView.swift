//
//  OnboardingPassportView.swift
//  MFElite
//
//  Step 6 — Passport: the "you're in" moment. A white inverse member card on
//  black, then "Enter the academy" to finish onboarding.
//

import SwiftUI

struct OnboardingPassportView: View {
    let state: OnboardingState
    let isFinishing: Bool
    let onEnter: () -> Void

    @State private var reveal = false
    @State private var showAvatarPicker = false
    @State private var profile = PlayerProfileStore.shared

    private var classYear: Int? { state.classYear }
    private var classYearText: String { classYear.map(String.init) ?? "—" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            DiagonalStripes(opacity: 0.4)

            VStack(alignment: .leading, spacing: 0) {
                ChapterEyebrow(number: 5, label: "Welcome")
                    .padding(.top, DS.Spacing.s12)

                Text("Welcome to MF, \(firstName).")
                    .font(.system(size: 38, weight: .heavy))
                    .tracking(-1.4)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s12)

                Text(classYear.map { "You are now Class of \(String($0)). Your first session starts now." } ?? "Your first session starts now.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .padding(.top, DS.Spacing.s8)

                Spacer()

                MemberCardView(
                    player: cardInfo,
                    avatarPhoto: profile.avatarPhoto,
                    width: cardWidth,
                    onPhotoTap: { showAvatarPicker = true }
                )
                .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
                .scaleEffect(reveal ? 1 : 0.92)
                .opacity(reveal ? 1 : 0)
                .frame(maxWidth: .infinity)

                Spacer()

                footer
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .onAppear {
            withAnimation(DS.Motion.celebrationSpring) { reveal = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerSheet()
        }
    }

    private var firstName: String {
        state.playerName.split(separator: " ").first.map(String.init) ?? "Player"
    }

    /// Card width inside the screen padding, capped so it stays poster-proportioned.
    private var cardWidth: CGFloat {
        min(UIScreen.main.bounds.width - DS.Spacing.s20 * 2, 360)
    }

    /// Live identity snapshot, mirrored straight from the onboarding state + profile.
    private var cardInfo: CardPlayerInfo {
        CardPlayerInfo(
            name: state.playerName.isEmpty ? "Player" : state.playerName,
            rankNumeral: "I",
            rankTitle: "Recruit",
            xp: 0,
            streak: 0,
            position: state.positionName,
            positionCode: state.positionCode,
            kitNumber: state.kitNumber,
            foot: state.foot,
            classYearText: classYearText,
            academy: "MF Elite",
            initials: state.initials,
            avatar: profile.avatar
        )
    }

    private var footer: some View {
        VStack(spacing: DS.Spacing.s16) {
            PrimaryButton(label: isFinishing ? "Entering…" : "Enter the academy") {
                onEnter()
            }
            .disabled(isFinishing)
            legalConsent
            StepBar(filled: OnboardingStep.stepTotal, total: OnboardingStep.stepTotal)
        }
        .padding(.bottom, DS.Spacing.s24)
    }

    private var legalConsent: some View {
        Text("By continuing you agree to our Terms of Use and Privacy Policy. These can be reviewed anytime in Settings.")
            .style(.micro)
            .foregroundStyle(DS.Colors.Ink.quaternary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    let state: OnboardingState = {
        let s = OnboardingState()
        s.playerName = "Marcus Bell"
        s.kitNumber = "10"
        s.foot = "Right"
        return s
    }()
    OnboardingPassportView(state: state, isFinishing: false, onEnter: {})
}
