//
//  NotificationPromptSheet.swift
//  MFElite
//
//  Soft pre-permission sheet shown after the player's first logged drill. Tapping
//  "Turn on reminders" triggers the real iOS system prompt; "Maybe later" defers.
//

import SwiftUI

struct NotificationPromptSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct Benefit: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let benefits: [Benefit] = [
        Benefit(icon: "sun.max", title: "Daily reminder", detail: "A nudge each morning so training never slips."),
        Benefit(icon: "flame", title: "Streak alerts", detail: "We'll warn you before a streak is about to break."),
        Benefit(icon: "rosette", title: "Milestone celebrations", detail: "Get a ping when you hit a new rank or milestone.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: DS.Spacing.s40)

            Image(systemName: "bell.badge")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(DS.Colors.Ink.primary)

            Text("Stay on track")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s20)

            VStack(spacing: DS.Spacing.s16) {
                ForEach(benefits) { benefit in
                    HStack(spacing: DS.Spacing.s16) {
                        Image(systemName: benefit.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(width: 40, height: 40)
                            .background(DS.Colors.Bg.raised)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(benefit.title)
                                .style(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(DS.Colors.Ink.primary)
                            Text(benefit.detail)
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.top, DS.Spacing.s32)
            .padding(.horizontal, DS.Spacing.s20)

            Spacer()

            VStack(spacing: DS.Spacing.s12) {
                PrimaryButton(label: "Turn on reminders") {
                    NotificationService.shared.requestPermission { _ in
                        dismiss()
                    }
                }
                GhostButton(label: "Maybe later") { dismiss() }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s24)
        }
        .frame(maxWidth: .infinity)
        .background(DS.Colors.Bg.base)
        .onAppear { EngagementTracker.shared.markNotificationAsked() }
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        NotificationPromptSheet()
            .preferredColorScheme(.dark)
    }
}
