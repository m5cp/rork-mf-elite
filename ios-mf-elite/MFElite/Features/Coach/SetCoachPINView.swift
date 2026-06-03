//
//  SetCoachPINView.swift
//  MFElite
//
//  First-login (and "Change PIN") flow for securing the coach workspace with a
//  custom 4-digit PIN, stored as a SHA256 hash in the Keychain.
//

import SwiftUI

/// Two-stage PIN entry: enter a new PIN, then confirm it. On match the hash is
/// saved and `onDone` fires. `onSkip` defers setup to the next login.
struct SetCoachPINView: View {
    let onDone: () -> Void
    var onSkip: (() -> Void)?

    private enum Stage {
        case enter
        case confirm
    }

    @State private var stage: Stage = .enter
    @State private var firstEntry: String = ""
    @State private var entry: String = ""
    @State private var shake: CGFloat = 0
    @FocusState private var focused: Bool

    private let maxDigits = 4

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "lock.rotation")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(DS.Colors.Ink.primary)

                Eyebrow(text: "Secure your workspace")
                    .padding(.top, DS.Spacing.s20)

                Text(stage == .enter ? "Set a new PIN" : "Confirm your PIN")
                    .style(.title1)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s12)

                Text(stage == .enter
                     ? "Choose a 4-digit PIN only you know. It replaces the default passcode."
                     : "Re-enter your PIN to confirm.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, DS.Spacing.s12)

                pinIndicators
                    .padding(.top, DS.Spacing.s40)
                    .offset(x: shake)

                Spacer()

                if let onSkip {
                    GhostButton(label: "Skip for now", action: onSkip)
                        .padding(.bottom, DS.Spacing.s16)
                }
            }
            .padding(.horizontal, DS.Spacing.s20)

            TextField("", text: $entry)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.001)
                .frame(width: 1, height: 1)
                .onChange(of: entry) { _, newValue in handleChange(newValue) }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { focused = true }
    }

    private var pinIndicators: some View {
        HStack(spacing: DS.Spacing.s16) {
            ForEach(0..<maxDigits, id: \.self) { index in
                Circle()
                    .fill(index < entry.count ? Color.white : Color.clear)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle().stroke(
                            index < entry.count ? Color.white : DS.Colors.Line.subtle,
                            lineWidth: 1
                        )
                    )
            }
        }
    }

    private func handleChange(_ newValue: String) {
        let digits = String(newValue.filter(\.isNumber).prefix(maxDigits))
        if digits != newValue {
            entry = digits
            return
        }
        guard digits.count == maxDigits else { return }

        switch stage {
        case .enter:
            firstEntry = digits
            entry = ""
            withAnimation(DS.Motion.standardSpring) { stage = .confirm }
        case .confirm:
            if digits == firstEntry {
                CoachPINStore.setPIN(digits)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                focused = false
                onDone()
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                triggerShake()
                entry = ""
                firstEntry = ""
                withAnimation(DS.Motion.standardSpring) { stage = .enter }
            }
        }
    }

    private func triggerShake() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.25)) { shake = 10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.35)) { shake = 0 }
        }
    }
}

#Preview {
    SetCoachPINView(onDone: {}, onSkip: {})
        .preferredColorScheme(.dark)
}
