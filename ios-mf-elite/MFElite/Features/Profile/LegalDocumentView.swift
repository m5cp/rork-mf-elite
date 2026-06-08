//
//  LegalDocumentView.swift
//  MFElite
//
//  Reusable container for in-app legal documents (Terms, Privacy, etc.).
//

import SwiftUI

struct LegalSection: Identifiable {
    let id = UUID()
    let heading: String
    let body: String
}

struct LegalDocumentView: View {
    let title: String
    let subtitle: String
    let intro: String
    let sections: [LegalSection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Legal")

                Text(title)
                    .style(.title1)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s8)

                Eyebrow(text: subtitle)
                    .padding(.top, DS.Spacing.s8)

                Text(intro)
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .padding(.top, DS.Spacing.s16)

                ForEach(sections) { sec in
                    Text(sec.heading)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(.top, DS.Spacing.s24)

                    Text(sec.body)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .padding(.top, DS.Spacing.s8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}
