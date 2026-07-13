//
//  Avatar.swift
//  MFElite
//
//  A small circular avatar with concentric ring effect.
//

import SwiftUI

struct Avatar: View {
    var size: CGFloat = 40
    var initials: String = "OK"

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hex: "#2A2A2A"),
                        Color(hex: "#161616"),
                        Color(hex: "#0A0A0A")
                    ],
                    center: UnitPoint(x: 0.32, y: 0.30),
                    startRadius: 0,
                    endRadius: size * 0.9
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(.white)
            )
            .goldRing()
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        HStack(spacing: 16) {
            Avatar(size: 40)
            Avatar(size: 64, initials: "MF")
        }
    }
}
