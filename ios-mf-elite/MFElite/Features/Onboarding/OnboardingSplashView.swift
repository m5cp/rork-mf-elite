//
//  OnboardingSplashView.swift
//  MFElite
//
//  Step 0 — pure-black ceremonial splash: stripe texture, the MF mark, and a
//  thin animated loading bar. No text. Auto-advances after 2.5s or on tap.
//

import SwiftUI

struct OnboardingSplashView: View {
    let state: OnboardingState
    @State private var appeared = false
    @State private var barFill: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            DiagonalStripes(opacity: 0.4)

            Image("mf-logo-white")
                .resizable()
                .scaledToFit()
                .frame(height: 280)
                .opacity(appeared ? 1 : 0)
                .accessibilityLabel("MF Elite")

            VStack {
                Spacer()
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 80, height: 1.5)
                    Capsule()
                        .fill(Color.white.opacity(0.40))
                        .frame(width: 80 * barFill, height: 1.5)
                }
                .padding(.bottom, DS.Spacing.s80)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { state.advance() }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.3)) { barFill = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if state.step == .splash { state.advance() }
            }
        }
    }
}

#Preview {
    OnboardingSplashView(state: OnboardingState())
}
