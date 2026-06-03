//
//  OnboardingPledgeView.swift
//  MFElite
//

import SwiftUI

struct OnboardingPledgeView: View {
    let state: OnboardingState

    private struct Pledge: Identifiable {
        let id = UUID()
        let eyebrow: String
        let title: String
        let body: String
    }

    private let pledges = [
        Pledge(eyebrow: "Recovery", title: "I will recover properly",
               body: "Sleep, nutrition, and rest are part of training."),
        Pledge(eyebrow: "Standard", title: "I will hold the standard",
               body: "Every session, every drill, full effort — no shortcuts."),
        Pledge(eyebrow: "Elite", title: "I will train like the elite",
               body: "Discipline, accountability, and growth — every single day.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Step 5 of 7")
                    Text("The Pledge")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("This is your commitment to the academy.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)

                    VStack(spacing: DS.Spacing.s12) {
                        ForEach(pledges) { pledge in
                            Card {
                                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                                    Eyebrow(text: pledge.eyebrow)
                                    Text(pledge.title)
                                        .style(.title3)
                                        .foregroundStyle(DS.Colors.Ink.primary)
                                    Text(pledge.body)
                                        .style(.foot)
                                        .foregroundStyle(DS.Colors.Ink.tertiary)
                                }
                            }
                        }
                    }
                    .padding(.top, DS.Spacing.s24)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s48)
            }

            PrimaryButton(label: "I pledge") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                state.advance()
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s24)
        }
    }
}

#Preview {
    OnboardingPledgeView(state: OnboardingState())
        .background(DS.Colors.Bg.base)
}
