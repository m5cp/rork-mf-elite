//
//  OnboardingSplashView.swift
//  MFElite
//

import SwiftUI

struct OnboardingSplashView: View {
    let state: OnboardingState
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: DS.Spacing.s20) {
                Image("LogoMark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.white)

                Text("By invitation")
                    .font(.system(size: 36, weight: .heavy).italic())
                    .tracking(-1.1)
                    .foregroundStyle(.white)
            }
            .opacity(appeared ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { state.advance() }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if state.step == .splash { state.advance() }
            }
        }
    }
}

#Preview {
    OnboardingSplashView(state: OnboardingState())
}
