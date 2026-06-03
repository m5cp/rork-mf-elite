//
//  OnboardingPassportView.swift
//  MFElite
//

import SwiftUI

struct OnboardingPassportView: View {
    let state: OnboardingState
    let isFinishing: Bool
    let onEnter: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Monogram(size: 120, initials: state.initials, kit: state.kitNumber)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)

                Eyebrow(text: "Academy Passport Issued")
                    .padding(.top, DS.Spacing.s24)

                Text(state.playerName.isEmpty ? "Player One" : state.playerName)
                    .style(.hero)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DS.Spacing.s8)

                Eyebrow(text: "Rank I · Trialist · 0 XP", color: DS.Colors.Ink.quaternary)
                    .padding(.top, DS.Spacing.s8)

                Text("Your journey begins. Every drill, every rep, every day.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DS.Spacing.s16)
                    .padding(.horizontal, DS.Spacing.s32)
            }
            .opacity(appeared ? 1 : 0)

            Spacer()

            PrimaryButton(label: isFinishing ? "Entering…" : "Enter the academy") {
                onEnter()
            }
            .disabled(isFinishing)
            .opacity(isFinishing ? 0.6 : 1)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s24)
        }
        .onAppear {
            withAnimation(DS.Motion.celebrationSpring) { appeared = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

#Preview {
    let state = OnboardingState()
    state.playerName = "Marcus Bell"
    state.kitNumber = "10"
    return OnboardingPassportView(state: state, isFinishing: false) {}
        .background(DS.Colors.Bg.base)
}
