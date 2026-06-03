//
//  PremiumWelcomeView.swift
//  MFElite
//
//  Shown immediately after a successful purchase.
//

import SwiftUI

struct PremiumWelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var glow: Bool = false

    private let perks = ["All Levels", "Certifications", "Film Library", "Streak Freezes"]

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                CertSeal(size: 100, earned: true)
                    .shadow(color: Color.white.opacity(glow ? 0.45 : 0.15), radius: glow ? 40 : 18)
                    .scaleEffect(glow ? 1.03 : 0.97)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glow)

                Text("Welcome to\nMF Elite")
                    .style(.hero)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-6)
                    .padding(.top, DS.Spacing.s24)

                Text("Every drill. Every level. Every certification. Your full academy journey starts now.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, DS.Spacing.s12)

                perkPills
                    .padding(.top, DS.Spacing.s24)

                Spacer()

                PrimaryButton(label: "Start training") { dismiss() }
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.bottom, DS.Spacing.s32)
            }
        }
        .onAppear {
            glow = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private var perkPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s8) {
                ForEach(perks, id: \.self) { perk in
                    Text(perk)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .padding(.vertical, DS.Spacing.s8)
                        .padding(.horizontal, DS.Spacing.s12)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.pill)
                                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
    }
}

#Preview {
    PremiumWelcomeView()
        .preferredColorScheme(.dark)
}
