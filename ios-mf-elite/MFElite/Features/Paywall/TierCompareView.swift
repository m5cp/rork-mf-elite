//
//  TierCompareView.swift
//  MFElite
//
//  A detailed Free vs Elite comparison, grouped by discipline.
//

import SwiftUI

/// Navigation route to the tier comparison screen.
struct TierCompareRoute: Hashable {}

struct TierCompareView: View {
    @Environment(SubscriptionService.self) private var subscription

    private struct FeatureGroup: Identifiable {
        let id = UUID()
        let title: String
        let rows: [(label: String, free: Bool)]
    }

    private let groups: [FeatureGroup] = [
        FeatureGroup(title: "Technical", rows: [
            ("Level 1 drills", true),
            ("Ball mastery levels 2–5", false),
            ("First touch & passing levels", false)
        ]),
        FeatureGroup(title: "Physical", rows: [
            ("Foundation conditioning", true),
            ("Speed & agility progressions", false),
            ("Strength & power levels", false)
        ]),
        FeatureGroup(title: "Tactical", rows: [
            ("Intro film session", true),
            ("Full tactical film library", false),
            ("Positioning & scanning units", false)
        ]),
        FeatureGroup(title: "Psychological", rows: [
            ("Daily mindset quote", true),
            ("Mind training exercises", false),
            ("Certifications & parent reports", false)
        ])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ForEach(groups) { group in
                    groupSection(group)
                }
                upgradeCTA
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Free vs Elite")
            Text("Compare plans")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s8)

            HStack {
                Spacer()
                Text("Free")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .frame(width: 52)
                Text("Elite")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .frame(width: 52, height: 22)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
            }
            .padding(.top, DS.Spacing.s24)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    private func groupSection(_ group: FeatureGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: group.title)
                .padding(.bottom, DS.Spacing.s4)

            ForEach(Array(group.rows.enumerated()), id: \.offset) { _, row in
                VStack(spacing: 0) {
                    Hairline()
                    HStack {
                        Text(row.label)
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Spacer()
                        marker(row.free).frame(width: 52)
                        marker(true).frame(width: 52)
                    }
                    .padding(.vertical, DS.Spacing.s12 + 2)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    private func marker(_ included: Bool) -> some View {
        Image(systemName: included ? "checkmark" : "xmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(included ? DS.Colors.Ink.primary : DS.Colors.Ink.disabled)
    }

    private var upgradeCTA: some View {
        PrimaryButton(label: "Upgrade to Elite") {
            subscription.presentPaywall()
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }
}
