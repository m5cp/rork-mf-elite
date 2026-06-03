//
//  PhotoPlaceholder.swift
//  MFElite
//
//  A striped placeholder surface used as the loading/empty state
//  for drill demo thumbnails.
//

import SwiftUI

struct PhotoPlaceholder: View {
    var height: CGFloat = 200
    var label: String = "COACH FILM"

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Diagonal stripe pattern at 115°.
            Canvas { context, size in
                let stripeWidth: CGFloat = 18
                let angle = Angle(degrees: 115).radians
                // Slope of stripes — shift x along the diagonal.
                let diagonal = size.width + size.height
                let slope = cos(angle) / sin(angle)
                var offset: CGFloat = -size.height * abs(slope)
                var index = 0
                while offset < diagonal {
                    let fill = index % 2 == 0
                        ? Color(hex: "#0E0E0E")
                        : Color(hex: "#141414")
                    var path = Path()
                    let x0 = offset
                    let x1 = offset + stripeWidth
                    path.move(to: CGPoint(x: x0, y: 0))
                    path.addLine(to: CGPoint(x: x1, y: 0))
                    path.addLine(to: CGPoint(x: x1 - size.height * slope, y: size.height))
                    path.addLine(to: CGPoint(x: x0 - size.height * slope, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(fill))
                    offset += stripeWidth
                    index += 1
                }
            }

            // Darker triangular corners for depth.
            Canvas { context, size in
                var left = Path()
                left.move(to: CGPoint(x: 0, y: 0))
                left.addLine(to: CGPoint(x: 0, y: size.height))
                left.addLine(to: CGPoint(x: size.width * 0.32, y: size.height))
                left.closeSubpath()
                context.fill(left, with: .color(Color.black.opacity(0.18)))

                var right = Path()
                right.move(to: CGPoint(x: size.width, y: 0))
                right.addLine(to: CGPoint(x: size.width, y: size.height))
                right.addLine(to: CGPoint(x: size.width * 0.68, y: 0))
                right.closeSubpath()
                context.fill(right, with: .color(Color.black.opacity(0.12)))
            }

            Eyebrow(text: "▸ " + label, color: Color.white.opacity(0.78))
                .padding(14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        PhotoPlaceholder()
            .padding(.horizontal, DS.Spacing.s20)
    }
}
