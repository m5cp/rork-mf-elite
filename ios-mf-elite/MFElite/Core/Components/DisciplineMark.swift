//
//  DisciplineMark.swift
//  MFElite
//
//  Four geometric glyphs representing the four training disciplines.
//  Stroked outlines only — never filled.
//

import SwiftUI

struct DisciplineMark: View {
    let kind: String
    var size: CGFloat = 26
    var color: Color = .white
    var strokeWidth: CGFloat = 1.5

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let path: Path

            switch kind {
            case "square":
                let inset = canvasSize.width * 0.18
                let rect = CGRect(
                    x: inset,
                    y: inset,
                    width: canvasSize.width - inset * 2,
                    height: canvasSize.height - inset * 2
                )
                path = Path(roundedRect: rect, cornerRadius: 1.5)

            case "triangle":
                let radius = canvasSize.width * 0.40
                path = polygon(center: center, radius: radius, sides: 3, rotation: -90)

            case "diamond":
                let radius = canvasSize.width * 0.40
                path = polygon(center: center, radius: radius, sides: 4, rotation: -90)

            case "circle":
                let radius = canvasSize.width * 0.36
                path = Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))

            default:
                path = Path()
            }

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: strokeWidth, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }

    private func polygon(center: CGPoint, radius: CGFloat, sides: Int, rotation: Double) -> Path {
        var path = Path()
        for i in 0..<sides {
            let angle = Angle(degrees: rotation + Double(i) / Double(sides) * 360).radians
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        HStack(spacing: 20) {
            DisciplineMark(kind: "square")
            DisciplineMark(kind: "triangle")
            DisciplineMark(kind: "diamond")
            DisciplineMark(kind: "circle")
        }
    }
}
