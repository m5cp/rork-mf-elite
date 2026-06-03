//
//  CoachLoginView.swift
//  MFElite
//
//  Admin gate for the coach workspace. Accepts the default PIN (1234) only until
//  the coach sets a custom PIN, which is stored as a SHA256 hash in the Keychain.
//

import SwiftUI
import SwiftData

/// Coordinates the passcode gate, the first-login PIN setup, and the workspace.
struct CoachLoginView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case gate
        case setPIN
        case workspace
    }

    @State private var phase: Phase = .gate

    var body: some View {
        switch phase {
        case .gate:
            CoachPasscodeGate(
                onUnlock: {
                    // First login (no custom PIN yet) routes through PIN setup.
                    phase = CoachPINStore.hasCustomPIN ? .workspace : .setPIN
                },
                onCancel: { dismiss() }
            )
        case .setPIN:
            SetCoachPINView(
                onDone: { phase = .workspace },
                onSkip: { phase = .workspace }
            )
        case .workspace:
            CoachWorkspaceView()
        }
    }
}

// MARK: - Passcode Gate

private struct CoachPasscodeGate: View {
    let onUnlock: () -> Void
    let onCancel: () -> Void

    @State private var entry: String = ""
    @State private var shake: CGFloat = 0
    @State private var showForgot = false
    @FocusState private var focused: Bool

    private let maxDigits = 4

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("mf-logo-white")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .accessibilityLabel("MF Elite")

                Eyebrow(text: "Admin · Coach Access")
                    .padding(.top, DS.Spacing.s12)

                Text("Coach Login")
                    .style(.title1)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s12)

                Text(CoachPINStore.hasCustomPIN
                     ? "Enter your coach PIN to access the admin workspace."
                     : "Enter the default coach passcode to access the admin workspace.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, DS.Spacing.s12)

                pinIndicators
                    .padding(.top, DS.Spacing.s40)
                    .offset(x: shake)

                Button {
                    showForgot = true
                } label: {
                    Text("Forgot PIN?")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, DS.Spacing.s24)

                Spacer()

                GhostButton(label: "Cancel", action: onCancel)
                    .padding(.bottom, DS.Spacing.s16)
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
        .alert("Forgot PIN?", isPresented: $showForgot) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Contact your academy administrator to reset the coach workspace PIN.")
        }
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

        if CoachPINStore.validate(digits) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            focused = false
            onUnlock()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            triggerShake()
            entry = ""
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
    CoachLoginView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [
            Discipline.self, Category.self, MasteryLevel.self,
            Drill.self, DrillProgress.self, PlayerState.self
        ])
}
