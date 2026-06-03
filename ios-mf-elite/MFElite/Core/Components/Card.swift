//
//  Card.swift
//  MFElite
//
//  A reusable surface container.
//

import SwiftUI

struct Card<Content: View>: View {
    var padding: CGFloat = 20
    var raised: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(DS.Colors.Line.hairline, lineWidth: 1)
            )
            .modifier(CardShadow(raised: raised))
    }
}

private struct CardShadow: ViewModifier {
    let raised: Bool

    func body(content: Content) -> some View {
        if raised {
            content.raisedElevation()
        } else {
            content.cardElevation()
        }
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        VStack(spacing: 16) {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Season 25 — 26")
                    Text("Default Card")
                        .style(.title2)
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
            }
            Card(raised: true) {
                Text("Raised Card")
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
    }
}
