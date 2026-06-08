//
//  DisciplineHero.swift
//  MFElite
//
//  A discipline-branded hero surface — a large SF Symbol on a subtle dark
//  gradient with diagonal line texture. Replaces PhotoPlaceholder. All white
//  on dark, no color.
//

import SwiftUI

struct DisciplineHero: View {
    var height: CGFloat = 200
    var disciplineName: String = ""
    var label: String = ""

    /// Maps discipline names to representative SF Symbols.
    private var icon: String {
        switch disciplineName.lowercased() {
        case "technical": return "figure.soccer"
        case "physical": return "figure.run"
        case "tactical": return "brain.head.profile"
        case "psychological": return "brain"
        default: return "sportscourt"
        }
    }

    var body: some View {
        ZStack {
            // Gradient background — subtle dark-to-slightly-less-dark.
            LinearGradient(
                colors: [
                    Color(hex: "#0E0E0E"),
                    Color(hex: "#1A1A1A"),
                    Color(hex: "#0E0E0E")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Large centered icon — bold white at low opacity.
            Image(systemName: icon)
                .font(.system(size: height * 0.35, weight: .thin))
                .foregroundStyle(Color.white.opacity(0.08))

            // Diagonal line texture overlay for depth.
            Canvas { context, size in
                let spacing: CGFloat = 24
                let count = Int(size.width / spacing) + Int(size.height / spacing)
                for i in 0..<count {
                    let offset = CGFloat(i) * spacing - size.height
                    var path = Path()
                    path.move(to: CGPoint(x: offset, y: size.height))
                    path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                    context.stroke(path, with: .color(Color.white.opacity(0.03)), lineWidth: 0.5)
                }
            }

            // Bottom label.
            if !label.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Text(label)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.white.opacity(0.78))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        VStack(spacing: 20) {
            DisciplineHero(height: 200, disciplineName: "Technical", label: "Drill · 1:00")
            DisciplineHero(height: 140, disciplineName: "Physical", label: "Physical")
        }
        .padding(.horizontal, DS.Spacing.s20)
    }
}
