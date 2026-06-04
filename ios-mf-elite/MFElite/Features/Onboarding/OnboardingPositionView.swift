//
//  OnboardingPositionView.swift
//  MFElite
//
//  Step 3 — Position: pick where you play on a top-down pitch, plus dominant foot.
//

import SwiftUI

struct OnboardingPositionView: View {
    let state: OnboardingState

    @State private var selected: PitchPosition?
    @State private var foot: String = "Right"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                ChapterEyebrow(number: 2, label: "Position")
                    .padding(.top, DS.Spacing.s12)

                Text("Where you live on the pitch.")
                    .font(.system(size: 40, weight: .heavy))
                    .tracking(-1.4)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s12)

                PitchDiagram(positions: PitchPosition.all, selected: $selected)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .padding(.top, DS.Spacing.s20)

                selectedInfo
                    .padding(.top, DS.Spacing.s16)

                footSelector
                    .padding(.top, DS.Spacing.s16)

                Spacer()

                footer
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .onAppear {
            selected = state.selectedPosition
            foot = state.foot
        }
    }

    private var selectedInfo: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Eyebrow(text: "Selected · Post")
                Text(selected.map { "\($0.name) · \($0.code.replacingOccurrences(of: "2", with: ""))" } ?? "Tap the pitch")
                    .style(.title1)
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            Spacer()
            Text("Tap to change")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
    }

    private var footSelector: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Dominant Foot")
            HStack(spacing: DS.Spacing.s12) {
                footPill("Right")
                footPill("Left")
            }
        }
    }

    private func footPill(_ value: String) -> some View {
        let active = foot == value
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) { foot = value }
        } label: {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(active ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(active ? Color.white : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(active ? Color.clear : DS.Colors.Line.subtle, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var footer: some View {
        VStack(spacing: DS.Spacing.s16) {
            PrimaryButton(label: selected.map { "Continue · \($0.name)" } ?? "Continue") {
                state.selectedPosition = selected
                state.foot = foot
                state.advance()
            }
            .opacity(selected == nil ? 0.4 : 1)
            .disabled(selected == nil)
            StepBar(filled: 3, total: OnboardingStep.stepTotal)
        }
        .padding(.bottom, DS.Spacing.s24)
    }
}

#Preview {
    OnboardingPositionView(state: OnboardingState())
}
