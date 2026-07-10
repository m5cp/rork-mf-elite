//
//  CertificationAwardView.swift
//  MFElite
//
//  The flagship celebration: a category fully certified. Shows the guilloché seal.
//

import SwiftUI
import UIKit
import StoreKit

struct CertificationAwardView: View {
    let category: Category
    let discipline: Discipline

    /// Called when the player taps "Continue training".
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var profile = PlayerProfileStore.shared
    @State private var revealSeal = false
    @State private var sharePreview: ShareMoment?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

                    Text("Your coach will sign this certification. It will appear on your player report and academy record.")
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
                    SecondaryButton(label: "Share this") { shareCertificate() }
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
                revealSeal = true
            } else {
                withAnimation(DS.Motion.celebrationSpring) {
                    revealSeal = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            // First certification is a genuine high point — ask for a review.
            if EngagementTracker.shared.shouldRequestReview(for: .firstCertification) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    requestReview()
                }
            }
        }
    }

    // MARK: - Certificate sharing

    /// Deep-links into the share flow with a branded "Certified" badge card
    /// preselected.
    private func shareCertificate() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sharePreview = ShareMomentBuilder.badge(.firstCert)
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

// MARK: - Shareable certificate card

/// A self-contained black certificate card rendered to an image for sharing.
private struct CertificateShareCard: View {
    let categoryName: String
    let disciplineName: String
    let playerName: String
    let dateEarned: Date

    private var dateText: String {
        dateEarned.formatted(.dateTime.month(.wide).day().year())
    }

    var body: some View {
        VStack(spacing: DS.Spacing.s20) {
            Text("MF ELITE ACADEMY")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(DS.Colors.Ink.tertiary)

            SealLarge(size: 120, earned: true)

            VStack(spacing: DS.Spacing.s8) {
                Text("SKILL CERTIFIED · \(disciplineName.uppercased())")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                Text(categoryName)
                    .style(.hero)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .multilineTextAlignment(.center)
                Text(playerName)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.secondary)
            }

            Text(dateText.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .padding(DS.Spacing.s40)
        .frame(width: 380)
        .background(DS.Colors.Bg.base)
    }
}
