//
//  PurchaseHelpView.swift
//  MFElite
//
//  Quiet help sheet for purchase problems. No pressure copy, no upsell: a
//  missing item is a coach's support-ledger fix; a refund is Apple's, always.
//

import SwiftUI

struct PurchaseHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let supportEmail = "mf.elitetraining@gmail.com"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        Eyebrow(text: "Purchase problem?")
                        Text("We're here to help")
                            .style(.title2)
                            .foregroundStyle(DS.Colors.Ink.primary)
                    }

                    helpCard(
                        icon: "person.text.rectangle",
                        title: "Didn't receive what you bought?",
                        body: "Your coach can credit the missing item directly to your account \u{2014} XP, a streak shield, or a booster. Reach out with your purchase details."
                    ) {
                        Button {
                            if let url = URL(string: "mailto:\(supportEmail)") { openURL(url) }
                        } label: {
                            Text("Email support")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ground.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressableButtonStyle())
                    }

                    helpCard(
                        icon: "creditcard",
                        title: "Want a refund?",
                        body: "Apple handles all payments for this app, so refunds are requested directly through Apple \u{2014} we can't process them ourselves."
                    ) {
                        Button {
                            if let url = URL(string: "https://reportaproblem.apple.com") { openURL(url) }
                        } label: {
                            Text("Request a refund from Apple")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ink.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .overlay(Capsule().stroke(DS.Colors.Line.subtle, lineWidth: 1))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s32)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func helpCard<Content: View>(icon: String, title: String, body: String, @ViewBuilder actions: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack(spacing: DS.Spacing.s12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.Bg.raised, in: Circle())
                Text(title)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            Text(body)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            actions()
        }
        .padding(DS.Spacing.s16)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
    }
}
