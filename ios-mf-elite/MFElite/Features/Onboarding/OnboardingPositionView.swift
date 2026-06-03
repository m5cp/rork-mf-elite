//
//  OnboardingPositionView.swift
//  MFElite
//

import SwiftUI

struct OnboardingPositionView: View {
    let state: OnboardingState
    @State private var selected: String = ""

    private let positions = ["Goalkeeper", "Defender", "Midfielder", "Forward", "Winger", "No preference"]
    private let columns = [GridItem(.flexible(), spacing: DS.Spacing.s12),
                           GridItem(.flexible(), spacing: DS.Spacing.s12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Step 3 of 6")
                    Text("Position")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Where do you play?")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)

                    LazyVGrid(columns: columns, spacing: DS.Spacing.s12) {
                        ForEach(positions, id: \.self) { option in
                            positionCard(option)
                        }
                    }
                    .padding(.top, DS.Spacing.s32)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s48)
            }

            PrimaryButton(label: "Continue") {
                state.position = selected
                state.advance()
            }
            .opacity(selected.isEmpty ? 0.4 : 1)
            .disabled(selected.isEmpty)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s24)
        }
        .onAppear { selected = state.position }
    }

    private func positionCard(_ option: String) -> some View {
        let isSelected = selected == option
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) { selected = option }
        } label: {
            Text(option)
                .style(.callout)
                .foregroundStyle(isSelected ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isSelected ? Color.white : DS.Colors.Bg.card)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(isSelected ? Color.clear : DS.Colors.Line.hairline, lineWidth: 1)
                )
                .modifier(ConditionalPillLight(active: isSelected))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct ConditionalPillLight: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.pillLightElevation() } else { content }
    }
}

#Preview {
    OnboardingPositionView(state: OnboardingState())
        .background(DS.Colors.Bg.base)
}
