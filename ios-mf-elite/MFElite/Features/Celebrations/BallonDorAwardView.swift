//
//  BallonDorAwardView.swift
//  MFElite
//
//  The app's biggest celebration: the invite-only Ballon d'Or tier, unlocked by a
//  coach's approval. Mirrors the certification award treatment with a golden
//  trophy and a personal "Invited by Coach …" line.
//

import SwiftUI
import UIKit

struct BallonDorAwardView: View {
    /// The coach who extended the invitation, when known.
    let coachName: String?
    /// Called when the player taps "Continue training".
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var profile = PlayerProfileStore.shared
    @State private var reveal = false
    @State private var shareImage: UIImage?
    @State private var showShare = false

    private static let gold = Color(red: 0.86, green: 0.71, blue: 0.36)
    private var goldGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.96, green: 0.85, blue: 0.52), Self.gold, Color(red: 0.70, green: 0.53, blue: 0.22)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            Circle()
                .fill(Self.gold.opacity(0.22))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .scaleEffect(reveal ? 1.08 : 0.9)
                .opacity(reveal ? 1 : 0)

            VStack(spacing: 0) {
                Spacer()

                trophy
                    .scaleEffect(reveal ? 1 : 0)

                VStack(spacing: DS.Spacing.s12) {
                    Eyebrow(text: "The Pinnacle · Invite Only")
                        .foregroundStyle(Self.gold)

                    Text("Ballon d'Or")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .multilineTextAlignment(.center)

                    if let coachName, !coachName.isEmpty {
                        Text("Invited by Coach \(coachName)")
                            .style(.title3)
                            .foregroundStyle(Self.gold)
                            .multilineTextAlignment(.center)
                    }

                    Text("The highest honour in the academy. Earned through relentless work and granted by your coach. This one is yours, \(ShareText.firstName(profile.displayName)).")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                .padding(.top, DS.Spacing.s24 + 4)

                Spacer()

                VStack(spacing: DS.Spacing.s12) {
                    PrimaryButton(label: "Continue training") {
                        onClose()
                        dismiss()
                    }
                    SecondaryButton(label: "Share this moment") { shareMoment() }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s40)
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShare) {
            if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if reduceMotion {
                reveal = true
            } else {
                withAnimation(DS.Motion.celebrationSpring) { reveal = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
    }

    private var trophy: some View {
        ZStack {
            Circle()
                .fill(DS.Colors.Bg.raised)
                .frame(width: 156, height: 156)
                .overlay(Circle().stroke(goldGradient, lineWidth: 2))
            Image(systemName: "trophy.fill")
                .font(.system(size: 68, weight: .semibold))
                .foregroundStyle(goldGradient)
        }
    }

    private func shareMoment() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let card = BallonDorShareCard(
            playerName: profile.displayName,
            coachName: coachName,
            date: Date()
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        if let image = renderer.uiImage {
            shareImage = image
            showShare = true
        }
    }
}

// MARK: - Shareable card

private struct BallonDorShareCard: View {
    let playerName: String
    let coachName: String?
    let date: Date

    private static let gold = Color(red: 0.86, green: 0.71, blue: 0.36)

    private var dateText: String {
        date.formatted(.dateTime.month(.wide).day().year())
    }

    var body: some View {
        VStack(spacing: DS.Spacing.s20) {
            Text("MF ELITE ACADEMY")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(DS.Colors.Ink.tertiary)

            Image(systemName: "trophy.fill")
                .font(.system(size: 90, weight: .semibold))
                .foregroundStyle(Self.gold)

            VStack(spacing: DS.Spacing.s8) {
                Text("THE PINNACLE · INVITE ONLY")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Self.gold)
                Text("Ballon d'Or")
                    .style(.hero)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Text(playerName)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                if let coachName, !coachName.isEmpty {
                    Text("Invited by Coach \(coachName)")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
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
