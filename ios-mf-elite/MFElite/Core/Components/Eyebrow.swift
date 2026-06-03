//
//  Eyebrow.swift
//  MFElite
//
//  Uppercase monospaced eyebrow label — the signature typographic device.
//

import SwiftUI

struct Eyebrow: View {
    let text: String
    var color: Color = DS.Colors.Ink.tertiary

    var body: some View {
        Text(text)
            .style(.micro)
            .foregroundStyle(color)
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        VStack(spacing: 16) {
            Eyebrow(text: "Season 25 — 26")
            Eyebrow(text: "Mastery Levels")
            Eyebrow(text: "Rank · II", color: DS.Colors.Ink.primary)
        }
    }
}
