//
//  SlashRule.swift
//  MFElite
//
//  Thin decorative divider with repeating diagonal slash marks echoing the MF logo motif.
//

import SwiftUI

struct SlashRule: View {
    var spacing: CGFloat = 18
    var slashLength: CGFloat = 18

    var body: some View {
        Canvas { context, size in
            let count = max(1, Int(size.width / spacing))
            // 115° from bottom-left to top-right.
            let angle = Angle(degrees: 115).radians
            let dx = cos(angle) * slashLength / 2
            let dy = sin(angle) * slashLength / 2
            let midY = size.height / 2

            for i in 0..<count {
                let x = spacing / 2 + CGFloat(i) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x - dx, y: midY + dy))
                path.addLine(to: CGPoint(x: x + dx, y: midY - dy))
                context.stroke(
                    path,
                    with: .color(DS.Colors.Line.subtle),
                    lineWidth: 1
                )
            }
        }
        .frame(height: 10)
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        SlashRule()
            .padding(.horizontal, DS.Spacing.s20)
    }
}
