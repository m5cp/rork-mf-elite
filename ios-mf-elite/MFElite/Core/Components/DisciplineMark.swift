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
    var color: Color = DS.Colors.Gold.base
    var strokeWidth: CGFloat = 2.0
    var metallic: Bool = true

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

            if metallic {
                let shading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [
                        Color(hex: "#FFF7D6"), Color(hex: "#F8DE95"), Color(hex: "#E8B84B"),
                        Color(hex: "#B07E1E"), Color(hex: "#795310")
                    ]),
                    startPoint: CGPoint(x: canvasSize.width / 2, y: 0),
                    endPoint: CGPoint(x: canvasSize.width / 2, y: canvasSize.height)
                )
                context.stroke(
                    path, with: shading,
                    style: StrokeStyle(lineWidth: strokeWidth, lineJoin: .round)
                )
                var highlight = context
                highlight.translateBy(x: 0, y: -strokeWidth * 0.4)
                highlight.stroke(
                    path, with: .color(Color.white.opacity(0.5)),
                    style: StrokeStyle(lineWidth: max(0.7, strokeWidth * 0.32), lineJoin: .round)
                )
            } else {
                context.stroke(
                    path, with: .color(color),
                    style: StrokeStyle(lineWidth: strokeWidth, lineJoin: .round)
                )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.45), radius: 2, y: 1.5)
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
