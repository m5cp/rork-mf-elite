//
//  CertSeal.swift
//  MFElite
//
//  Concentric guilloché certification seal — the prestige badge of the academy.
//

import SwiftUI

/// Small certification seal (~48pt default).
struct CertSeal: View {
    var size: CGFloat = 48
    var earned: Bool = false

    var body: some View {
        ZStack {
            SealRing(size: size, tickCount: 24, tickLength: 4)

            if earned {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.8, height: size * 0.8)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: size * 0.32, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                    )
            } else {
                Circle()
                    .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                    .frame(width: size * 0.8, height: size * 0.8)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Large certification seal (~160pt) with a breathing glow animation.
struct SealLarge: View {
    var size: CGFloat = 160
    var earned: Bool = false

    @State private var breathing = false

    var body: some View {
        ZStack {
            SealRing(size: size, tickCount: 48, tickLength: size * 0.045)

            if earned {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.8, height: size * 0.8)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: size * 0.32, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                    )
            } else {
                Circle()
                    .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                    .frame(width: size * 0.8, height: size * 0.8)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(breathing ? 1.04 : 0.96)
        .opacity(breathing ? 1.0 : 0.85)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

/// Shared outer ring + guilloché ticks.
private struct SealRing: View {
    let size: CGFloat
    let tickCount: Int
    let tickLength: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2 - 0.5

            // Outer ring
            let ringPath = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.stroke(ringPath, with: .color(DS.Colors.Line.subtle), lineWidth: 1)

            // Guilloché ticks
            let inner = radius - tickLength
            for i in 0..<tickCount {
                let angle = (Double(i) / Double(tickCount)) * 2 * .pi
                let cosA = CGFloat(cos(angle))
                let sinA = CGFloat(sin(angle))
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + cosA * inner, y: center.y + sinA * inner))
                tick.addLine(to: CGPoint(x: center.x + cosA * radius, y: center.y + sinA * radius))
                context.stroke(tick, with: .color(Color.white.opacity(0.20)), lineWidth: 1)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        VStack(spacing: DS.Spacing.s40) {
            HStack(spacing: DS.Spacing.s24) {
                CertSeal(earned: true)
                CertSeal(earned: false)
            }
            SealLarge(earned: true)
        }
    }
}
