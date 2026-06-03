//
//  OnboardingIdentifyView.swift
//  MFElite
//

import SwiftUI

struct OnboardingIdentifyView: View {
    let state: OnboardingState
    @FocusState private var focused: Bool
    @State private var name: String = ""

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Step 1 of 6")
                    Text("Identify")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("What should we call you?")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)

                    TextField("", text: $name, prompt: Text("Your name").foregroundColor(DS.Colors.Ink.quaternary))
                        .focused($focused)
                        .font(DS.Typography.title2)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .tint(.white)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .frame(height: 56)
                        .padding(.horizontal, DS.Spacing.s20)
                        .background(DS.Colors.Bg.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                        )
                        .padding(.top, DS.Spacing.s32)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s48)
            }

            PrimaryButton(label: "Continue") {
                state.playerName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                state.advance()
            }
            .opacity(canContinue ? 1 : 0.4)
            .disabled(!canContinue)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s24)
        }
        .onAppear {
            name = state.playerName
            focused = true
        }
    }
}

#Preview {
    OnboardingIdentifyView(state: OnboardingState())
        .background(DS.Colors.Bg.base)
}
