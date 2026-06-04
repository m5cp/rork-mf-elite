//
//  OnboardingNumberView.swift
//  MFElite
//
//  Step 5 — Your Number: a live monogram preview that updates as the player
//  taps a custom numeric keypad to claim a kit number.
//

import SwiftUI

struct OnboardingNumberView: View {
    let state: OnboardingState

    @State private var number: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                ChapterEyebrow(number: 4, label: "Your Number")
                    .padding(.top, DS.Spacing.s12)

                Text("Pick your number.")
                    .font(.system(size: 44, weight: .heavy))
                    .tracking(-1.6)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s12)

                Spacer(minLength: DS.Spacing.s16)

                monogramPreview
                    .frame(maxWidth: .infinity)

                Spacer(minLength: DS.Spacing.s16)

                NumberKeypad(value: $number, maxDigits: 2)

                Spacer(minLength: DS.Spacing.s16)

                footer
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .onAppear { number = state.kitNumber }
    }

    private var displayNumber: String { number.isEmpty ? "0" : number }

    private var monogramPreview: some View {
        VStack(spacing: DS.Spacing.s12) {
            Monogram(size: 168, initials: state.initials, kit: nil)
                .overlay {
                    Text(displayNumber)
                        .font(.system(size: 110, weight: .heavy))
                        .monospacedDigit()
                        .tracking(-4)
                        .foregroundStyle(.white)
                }
                .overlay(alignment: .topTrailing) {
                    Text("MF · \(state.positionCode)")
                        .style(.microSm)
                        .foregroundStyle(Color.white.opacity(0.78))
                        .padding(10)
                }

            Eyebrow(text: "\(state.positionName) · \(state.playerName.isEmpty ? "Athlete" : state.playerName)")
        }
    }

    private var footer: some View {
        VStack(spacing: DS.Spacing.s16) {
            PrimaryButton(label: "Take the number") {
                state.kitNumber = number.isEmpty ? "10" : number
                state.advance()
            }
            .opacity(number.isEmpty ? 0.4 : 1)
            .disabled(number.isEmpty)
            StepBar(filled: 6, total: 7)
        }
        .padding(.bottom, DS.Spacing.s24)
    }
}

#Preview {
    OnboardingNumberView(state: OnboardingState())
}
