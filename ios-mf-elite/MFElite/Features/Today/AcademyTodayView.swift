//
//  AcademyTodayView.swift
//  MFElite
//

import SwiftUI

struct AcademyTodayView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Tab 1 · Today")
                    Text("Academy Today")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Your daily dashboard — quote, goals, pathway progress, and recommendations. Coming in Prompt 2.")
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }

                PitchRing(progress: 2.0 / 3.0, value: "2/3", label: "Goals")
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
    AcademyTodayView()
        .preferredColorScheme(.dark)
}
