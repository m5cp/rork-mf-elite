//
//  OnboardingCodeView.swift
//  MFElite
//
//  Step 1 — "The Code": a creed slate (not a code entry). States the academy's
//  founding principle and lets the player commit with the arrow CTA.
//

import SwiftUI

struct OnboardingCodeView: View {
    let state: OnboardingState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            DiagonalStripes(opacity: 0.4)

            VStack(spacing: 0) {
                Image("mf-logo-white")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 56)
                    .padding(.top, DS.Spacing.s24)
                    .accessibilityLabel("MF Elite")

                Spacer()

                VStack(spacing: DS.Spacing.s20) {
                    Text("THE CODE")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(Color.white.opacity(0.75))

                    Text("One coach.\nOne athlete.\nOne purpose.")
                        .font(.system(size: 48, weight: .heavy))
                        .tracking(-1.6)
                        .lineSpacing(6)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: DS.Spacing.s16) {
                    SlashRule()
                    HStack {
                        ChapterEyebrow(number: 0, label: "The Code")
                        Spacer()
                        ArrowCTA(label: "I'm in") { state.advance() }
                    }
                    StepBar(filled: 1, total: 7)
                }
                .padding(.bottom, DS.Spacing.s32)
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
    }
}

#Preview {
    OnboardingCodeView(state: OnboardingState())
}
