//
//  SectionHead.swift
//  MFElite
//
//  A section heading with optional eyebrow above.
//

import SwiftUI

struct SectionHead: View {
    var eyebrow: String? = nil
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            if let eyebrow {
                Eyebrow(text: eyebrow)
            }
            Text(title)
                .style(.title2)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        VStack(alignment: .leading, spacing: DS.Spacing.s24) {
            SectionHead(eyebrow: "Development Pathways", title: "Master Your Craft")
            SectionHead(title: "Recent Sessions")
        }
        .padding(.horizontal, DS.Spacing.s20)
    }
}
