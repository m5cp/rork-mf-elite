//
//  OnboardingPledgeView.swift
//  MFElite
//
//  Step 4 — The Pledge: pick the commitment tier (Recovery / Standard / Elite).
//

import SwiftUI

struct OnboardingPledgeView: View {
    let state: OnboardingState

    @State private var selected: PledgeTier = .standard

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                ChapterEyebrow(number: 3, label: "The Pledge")
                    .padding(.top, DS.Spacing.s12)

                Text("How much will you give?")
                    .font(.system(size: 40, weight: .heavy))
                    .tracking(-1.4)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s12)

                ScrollView {
                    VStack(spacing: DS.Spacing.s12) {
                        ForEach(PledgeTier.allCases) { tier in
                            tierCard(tier)
                        }
                    }
                    .padding(.top, DS.Spacing.s24)
                    .padding(.bottom, DS.Spacing.s24)
                }
                .scrollIndicators(.hidden)

                footer
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .onAppear { selected = state.pledgeTier }
    }

    private func tierCard(_ tier: PledgeTier) -> some View {
        let active = selected == tier
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) { selected = tier }
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tier.title)
                        .style(.title2)
                        .foregroundStyle(active ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
                    Spacer()
                    Text(tier.meta)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(active ? DS.Colors.Ground.secondary : DS.Colors.Ink.tertiary)
                }
                Text(tier.quote)
                    .font(.system(size: 16, weight: .regular).italic())
                    .foregroundStyle(active ? DS.Colors.Ground.secondary : DS.Colors.Ink.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, DS.Spacing.s12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(active ? Color.black : Color.white.opacity(0.18))
                            .frame(width: 2)
                    }
            }
            .padding(DS.Spacing.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(active ? Color.white : DS.Colors.Line.subtle, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var footer: some View {
        VStack(spacing: DS.Spacing.s16) {
            PrimaryButton(label: "Sign the pledge") {
                state.pledgeTier = selected
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                state.advance()
            }
            StepBar(filled: 4)
        }
        .padding(.bottom, DS.Spacing.s24)
    }
}

#Preview {
    OnboardingPledgeView(state: OnboardingState())
}
