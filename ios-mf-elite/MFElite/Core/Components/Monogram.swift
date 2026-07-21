//
//  Monogram.swift
//  MFElite
//
//  A large square badge for player/rank cards.
//

import SwiftUI

struct Monogram: View {
    var size: CGFloat = 96
    var initials: String = "OK"
    var kit: String? = "09"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#1A1A1A"),
                            Color(hex: "#0A0A0A"),
                            Color(hex: "#050505")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Canvas { context, canvasSize in
                let spacing = canvasSize.width / 4
                for i in 1..<4 {
                    let offset = CGFloat(i) * spacing
                    var path = Path()
                    path.move(to: CGPoint(x: offset, y: canvasSize.height))
                    path.addLine(to: CGPoint(x: offset + canvasSize.height, y: 0))
                    context.stroke(
                        path,
                        with: .color(DS.Colors.Gold.base.opacity(0.10)),
                        lineWidth: 1
                    )
                }
            }

            Text(initials)
                .font(.system(size: size * 0.46, weight: .heavy))
                .tracking(-1.2)
                .foregroundStyle(.white)

            if let kit {
                VStack {
                    HStack {
                        Spacer()
                        Text("#\(kit)")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Gold.textLight)
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(DS.Colors.Gold.line, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.50), radius: 12, y: 10)
        .shadow(color: DS.Colors.Gold.faint, radius: 11)
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        Monogram()
    }
}
