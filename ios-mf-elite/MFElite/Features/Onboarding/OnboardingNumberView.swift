//
//  OnboardingNumberView.swift
//  MFElite
//

import SwiftUI

struct OnboardingNumberView: View {
    let state: OnboardingState
    @State private var number: Int = 10

    private let popular = [7, 9, 10, 11, 14, 23]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Step 6 of 7")
                    Text("Your Number")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Choose your academy kit number.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)

                    // Large number display
                    Text(String(format: "%02d", number))
                        .font(DS.Typography.num(size: 80))
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.s24)

                    // Popular numbers
                    Eyebrow(text: "Popular")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.s12), count: 3),
                              spacing: DS.Spacing.s12) {
                        ForEach(popular, id: \.self) { value in
                            numberPill(value)
                        }
                    }
                    .padding(.top, DS.Spacing.s4)

                    // Stepper for any number 1–99
                    HStack {
                        Eyebrow(text: "Any number")
                        Spacer()
                        Stepper(value: $number, in: 1...99) {
                            Text("\(number)")
                                .style(.num(size: 18))
                                .foregroundStyle(DS.Colors.Ink.primary)
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    .padding(.vertical, DS.Spacing.s12)
                    .padding(.horizontal, DS.Spacing.s16)
                    .background(DS.Colors.Bg.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .padding(.top, DS.Spacing.s20)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s48)
            }

            PrimaryButton(label: "Claim number") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                state.kitNumber = String(number)
                state.advance()
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s24)
        }
        .onAppear { number = Int(state.kitNumber) ?? 10 }
    }

    private func numberPill(_ value: Int) -> some View {
        let isSelected = number == value
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) { number = value }
        } label: {
            Text("\(value)")
                .style(.num(size: 20))
                .foregroundStyle(isSelected ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isSelected ? Color.white : DS.Colors.Bg.card)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(isSelected ? Color.clear : DS.Colors.Line.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    OnboardingNumberView(state: OnboardingState())
        .background(DS.Colors.Bg.base)
}
