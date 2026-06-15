//
//  OnboardingLevelView.swift
//  MFElite
//
//  Step 4 — Level: capture the player's starting skill level so the first
//  recommendations and sessions begin at the right place. Never locks content.
//

import SwiftUI

struct OnboardingLevelView: View {
    let state: OnboardingState

    @State private var selected: TrainingLevel?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                ChapterEyebrow(number: 3, label: "Your Level")
                    .padding(.top, DS.Spacing.s12)

                Text("What's your level?")
                    .font(.system(size: 40, weight: .heavy))
                    .tracking(-1.4)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s12)

                Text("We'll start your plan in the right place. Everything stays unlocked — you can go anywhere, anytime.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .padding(.top, DS.Spacing.s12)

                VStack(spacing: DS.Spacing.s12) {
                    ForEach(TrainingLevel.allCases) { level in
                        levelCard(level)
                    }
                }
                .padding(.top, DS.Spacing.s24)

                Spacer()

                footer
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .onAppear { selected = state.trainingLevel }
    }

    private func levelCard(_ level: TrainingLevel) -> some View {
        let active = selected == level
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) { selected = level }
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.s16) {
                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text(level.title)
                        .style(.title3)
                        .foregroundStyle(active ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
                    Text(level.subtitle)
                        .style(.micro)
                        .foregroundStyle(active ? DS.Colors.Ground.secondary : DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(active ? DS.Colors.Ground.primary : DS.Colors.Ink.quaternary)
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
        .accessibilityLabel("\(level.title). \(level.subtitle)")
    }

    private var footer: some View {
        VStack(spacing: DS.Spacing.s16) {
            PrimaryButton(label: selected.map { "Continue · \($0.title)" } ?? "Continue") {
                state.trainingLevel = selected
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                state.advance()
            }
            .opacity(selected == nil ? 0.4 : 1)
            .disabled(selected == nil)
            StepBar(filled: 4, total: OnboardingStep.stepTotal)
        }
        .padding(.bottom, DS.Spacing.s24)
    }
}

#Preview {
    OnboardingLevelView(state: OnboardingState())
        .preferredColorScheme(.dark)
}
