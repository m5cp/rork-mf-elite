//
//  StreakMilestoneView.swift
//  MFElite
//
//  Full-screen celebration shown once when the streak crosses a milestone tier
//  (7, 30, 50, 100 days). Mirrors the certification/Ballon d'Or treatment with
//  an ember-colored flame badge. Presentation only — streak, XP, and history
//  are already saved before this appears.
//

import SwiftUI
import SwiftData
import UIKit

struct StreakMilestoneView: View {
    /// The milestone tier being celebrated (7, 30, 50, or 100).
    let days: Int
    /// Called when the player taps "Keep going".
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var players: [PlayerState]

    @State private var profile = PlayerProfileStore.shared
    @State private var reveal = false
    @State private var sharePreview: ShareMoment?

    private static let ember = Color(red: 1.0, green: 0.55, blue: 0.16)

    private var emberGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.80, blue: 0.36),
                Self.ember,
                Color(red: 0.82, green: 0.28, blue: 0.08)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// One line of copy per tier.
    private var tierCopy: String {
        switch days {
        case 7: return "One full week. This is how habits start."
        case 30: return "A month of showing up. Elite is a habit."
        case 50: return "50 days. Most players never get here."
        case 100: return "100 days. Different animal."
        default: return "\(days) days of showing up."
        }
    }

    private var firstName: String {
        ShareText.firstName(profile.displayName)
    }

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            // Soft pulsing ember glow behind the flame.
            Circle()
                .fill(Self.ember.opacity(0.20))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .scaleEffect(reveal ? 1.08 : 0.9)
                .opacity(reveal ? 1 : 0)

            VStack(spacing: 0) {
                Spacer()

                flameBadge
                    .scaleEffect(reveal ? 1 : 0)

                VStack(spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Streak Milestone")
                        .foregroundStyle(Self.ember)

                    Text("\(days)-DAY STREAK")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .multilineTextAlignment(.center)

                    Text(tierCopy)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)

                    Text("This one is yours, \(firstName).")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.s24 + 4)
                .opacity(reveal ? 1 : 0)

                Spacer()

                VStack(spacing: DS.Spacing.s12) {
                    PrimaryButton(label: "Keep going") {
                        onClose()
                        dismiss()
                    }
                    SecondaryButton(label: "Share this") { share() }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s40)
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $sharePreview) { moment in
            SharePreviewView(moment: moment)
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if reduceMotion {
                reveal = true
            } else {
                withAnimation(DS.Motion.celebrationSpring) { reveal = true }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(days)-day streak milestone. \(tierCopy)")
    }

    private var flameBadge: some View {
        ZStack {
            Circle()
                .fill(DS.Colors.Bg.raised)
                .frame(width: 156, height: 156)
                .overlay(Circle().stroke(emberGradient, lineWidth: 2))
            Image(systemName: "flame.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(emberGradient)
        }
    }

    /// Deep-links into the share flow with this streak milestone preselected as
    /// a branded Streak card.
    private func share() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sharePreview = ShareMomentBuilder.streak(days: days)
    }
}

#Preview {
    StreakMilestoneView(days: 30, onClose: {})
}
