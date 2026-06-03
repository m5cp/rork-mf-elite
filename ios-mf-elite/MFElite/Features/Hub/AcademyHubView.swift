//
//  AcademyHubView.swift
//  MFElite
//

import SwiftUI

struct AcademyHubView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        Eyebrow(text: "Tab 2 · MF Hub")
                        Text("The Curriculum")
                            .style(.title1)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text("Four development pathways with mastery levels. Coming in Prompt 2.")
                            .style(.body)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }

                    HStack(spacing: DS.Spacing.s20) {
                        DisciplineMark(kind: "square")
                        DisciplineMark(kind: "triangle")
                        DisciplineMark(kind: "diamond")
                        DisciplineMark(kind: "circle")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
        }
    }
}

#Preview {
    AcademyHubView()
        .preferredColorScheme(.dark)
}
