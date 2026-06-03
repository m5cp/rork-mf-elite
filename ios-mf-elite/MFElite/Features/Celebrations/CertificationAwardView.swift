//
//  CertificationAwardView.swift
//  MFElite
//
//  The flagship celebration: a category fully certified. Shows the guilloché seal.
//

import SwiftUI

struct CertificationAwardView: View {
    let category: Category
    let discipline: Discipline

    /// Called when the player taps "Continue training".
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var revealSeal = false

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            // Soft pulsing glow behind the seal.
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .scaleEffect(revealSeal ? 1.06 : 0.9)
                .opacity(revealSeal ? 1 : 0)

            VStack(spacing: 0) {
                Spacer()

                SealLarge(earned: true)
                    .scaleEffect(revealSeal ? 1 : 0)

                VStack(spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Skill Certified · \(discipline.name)")
                        .foregroundStyle(DS.Colors.Ink.tertiary)

                    Text(category.certName)
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .multilineTextAlignment(.center)

                    Text("Your coach will sign this certification. It will appear on your parent report and academy record.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .padding(.top, DS.Spacing.s24 + 4)

                HStack(spacing: DS.Spacing.s8) {
                    rewardPill(text: "+\(ProgressionRules.xpCategoryCert) XP", icon: nil)
                    rewardPill(text: "Coach-signed", icon: "signature")
                }
                .padding(.top, DS.Spacing.s24)

                Spacer()

                VStack(spacing: DS.Spacing.s12) {
                    PrimaryButton(label: "Continue training") {
                        onClose()
                        dismiss()
                    }
                    SecondaryButton(label: "Share certificate") {}
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s40)
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(DS.Motion.celebrationSpring) {
                revealSeal = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    private func rewardPill(text: String, icon: String?) -> some View {
        HStack(spacing: DS.Spacing.s4 + 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            Text(text)
                .style(.foot)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .padding(.vertical, DS.Spacing.s8)
        .padding(.horizontal, DS.Spacing.s16)
        .background(DS.Colors.Bg.raised)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }
}
