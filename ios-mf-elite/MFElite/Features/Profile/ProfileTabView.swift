//
//  ProfileTabView.swift
//  MFElite
//

import SwiftUI

struct ProfileTabView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Tab 4 · Profile")
                    Text("Profile")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Your player card, settings, and academy credentials. Coming in a later prompt.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }

                Monogram(initials: "P1", kit: "09")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
    }
}

#Preview {
    ProfileTabView()
        .preferredColorScheme(.dark)
}
