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
    @State private var isCoach: Bool = false
    @State private var foot: String = "Right"

    /// True when the person has made any choice (a pitch spot or Coach).
    private var hasSelection: Bool { selected != nil || isCoach }

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

                PitchDiagram(positions: PitchPosition.all, selected: pitchSelection)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .padding(.top, DS.Spacing.s20)

                coachChip
                    .padding(.top, DS.Spacing.s16)

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
            isCoach = state.isCoach
            foot = state.foot
        }
    }

    /// Binding into the pitch: picking a spot clears the Coach choice.
    private var pitchSelection: Binding<PitchPosition?> {
        Binding(
            get: { selected },
            set: { newValue in
                selected = newValue
                if newValue != nil { isCoach = false }
            }
        )
    }

    private var coachChip: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) {
                isCoach.toggle()
                if isCoach { selected = nil }
            }
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: "figure.coach")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isCoach ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Coach")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isCoach ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
                    Text("On the sideline")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isCoach ? DS.Colors.Ground.primary.opacity(0.7) : DS.Colors.Ink.quaternary)
                }
                Spacer(minLength: 0)
                if isCoach {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                }
            }
            .padding(.horizontal, DS.Spacing.s16)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(isCoach ? Color.white : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isCoach ? Color.clear : DS.Colors.Line.subtle, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Coach, on the sideline")
        .accessibilityAddTraits(isCoach ? .isSelected : [])
    }

    private var selectedInfo: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                Eyebrow(text: "Selected · Post")
                Text(selectedLabel)
                    .style(.title1)
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            Spacer()
            Text("Tap to change")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
    }

    private var selectedLabel: String {
        if isCoach { return "Coach · Sideline" }
        if let selected { return "\(selected.name) · \(selected.code.replacingOccurrences(of: "2", with: ""))" }
        return "Tap the pitch"
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

    private var continueLabel: String {
        if isCoach { return "Continue · Coach" }
        if let selected { return "Continue · \(selected.name)" }
        return "Continue"
    }

    private var footer: some View {
        VStack(spacing: DS.Spacing.s16) {
            PrimaryButton(label: continueLabel) {
                state.selectedPosition = selected
                state.isCoach = isCoach
                state.foot = foot
                state.advance()
            }
            .opacity(hasSelection ? 1 : 0.4)
            .disabled(!hasSelection)
            StepBar(filled: 3, total: OnboardingStep.stepTotal)
        }
        .padding(.bottom, DS.Spacing.s24)
    }
}

#Preview {
    OnboardingPositionView(state: OnboardingState())
}
