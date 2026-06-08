//
//  OnboardingPassportView.swift
//  MFElite
//
//  Step 6 — Passport: the "you're in" moment. A white inverse member card on
//  black, then "Enter the academy" to finish onboarding.
//

import SwiftUI

struct OnboardingPassportView: View {
    let state: OnboardingState
    let isFinishing: Bool
    let onEnter: () -> Void

    @State private var reveal = false
    @State private var showAvatarPicker = false
    @State private var profile = PlayerProfileStore.shared

    private var classYear: Int? { state.classYear }
    private var classYearText: String { classYear.map(String.init) ?? "—" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            DiagonalStripes(opacity: 0.4)

            VStack(alignment: .leading, spacing: 0) {
                ChapterEyebrow(number: 5, label: "Welcome")
                    .padding(.top, DS.Spacing.s12)

                Text("Welcome to MF, \(firstName).")
                    .font(.system(size: 38, weight: .heavy))
                    .tracking(-1.4)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s12)

                Text(classYear.map { "You are now Class of \(String($0)). Your first session starts now." } ?? "Your first session starts now.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .padding(.top, DS.Spacing.s8)

                Spacer()

                passportCard
                    .scaleEffect(reveal ? 1 : 0.92)
                    .opacity(reveal ? 1 : 0)

                Spacer()

                footer
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .onAppear {
            withAnimation(DS.Motion.celebrationSpring) { reveal = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerSheet()
        }
    }

    private var firstName: String {
        state.playerName.split(separator: " ").first.map(String.init) ?? "Player"
    }

    // MARK: - Passport card

    private var passportCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s16) {
            HStack {
                Image("mf-logo-black")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
                    .accessibilityLabel("MF Elite")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("MF · ACADEMY")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(DS.Colors.Ground.secondary)
                    Text("CLASS · \(classYearText)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(DS.Colors.Ground.tertiary)
                }
            }

            HStack(alignment: .top, spacing: DS.Spacing.s16) {
                photoBox
                identityFields
            }

            slashRuleBlack

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACADEMY")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(DS.Colors.Ground.tertiary)
                    Text("MF Elite")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                }
                Spacer()
                Text(state.kitNumber.isEmpty ? "MF" : "№ \(state.kitNumber)")
                    .font(DS.Typography.num(size: 14))
                    .foregroundStyle(DS.Colors.Ground.primary)
            }
        }
        .padding(DS.Spacing.s20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
    }

    private var photoBox: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showAvatarPicker = true
        } label: {
            AvatarView(
                selection: profile.avatar,
                photo: profile.avatarPhoto,
                initials: profile.initials,
                kit: nil,
                size: 92,
                shape: .roundedRect(DS.Radius.sm)
            )
            .frame(height: 116, alignment: .top)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 24, height: 24)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
                    .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Change avatar")
    }

    private var identityFields: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NAME")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(DS.Colors.Ground.tertiary)
                Text(state.playerName.isEmpty ? "Player" : state.playerName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            HStack(spacing: 0) {
                fieldCell("POST", state.positionCode)
                fieldCell("KIT", state.kitNumber.isEmpty ? "—" : state.kitNumber)
            }
            HStack(spacing: 0) {
                fieldCell("FOOT", state.foot)
                fieldCell("CLASS", classYearText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(DS.Colors.Ground.tertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Colors.Ground.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var slashRuleBlack: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            let count = max(1, Int(size.width / spacing))
            let angle = Angle(degrees: 115).radians
            let dx = cos(angle) * 9
            let dy = sin(angle) * 9
            let midY = size.height / 2
            for i in 0..<count {
                let x = spacing / 2 + CGFloat(i) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x - dx, y: midY + dy))
                path.addLine(to: CGPoint(x: x + dx, y: midY - dy))
                context.stroke(path, with: .color(.black.opacity(0.15)), lineWidth: 1)
            }
        }
        .frame(height: 10)
    }

    private var footer: some View {
        VStack(spacing: DS.Spacing.s16) {
            PrimaryButton(label: isFinishing ? "Entering…" : "Enter the academy") {
                onEnter()
            }
            .disabled(isFinishing)
            legalConsent
            StepBar(filled: OnboardingStep.stepTotal, total: OnboardingStep.stepTotal)
        }
        .padding(.bottom, DS.Spacing.s24)
    }

    private var legalConsent: some View {
        Text("By continuing you agree to our Terms of Use and Privacy Policy. These can be reviewed anytime in Settings.")
            .style(.micro)
            .foregroundStyle(DS.Colors.Ink.quaternary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    let state: OnboardingState = {
        let s = OnboardingState()
        s.playerName = "Marcus Bell"
        s.kitNumber = "10"
        s.foot = "Right"
        return s
    }()
    OnboardingPassportView(state: state, isFinishing: false, onEnter: {})
}
