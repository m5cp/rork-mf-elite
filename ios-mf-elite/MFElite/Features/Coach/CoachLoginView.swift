//
//  CoachLoginView.swift
//  MFElite
//
//  Admin gate for the coach workspace. A simple 4-digit passcode — not real auth.
//

import SwiftUI
import SwiftData

/// Hardcoded MVP passcode for the coach workspace.
private let coachPasscode = "1234"

/// Presents the passcode gate, then swaps to the workspace once unlocked.
struct CoachLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var unlocked = false

    var body: some View {
        if unlocked {
            CoachWorkspaceView()
        } else {
            CoachPasscodeGate(
                onUnlock: { unlocked = true },
                onCancel: { dismiss() }
            )
        }
    }
}

private struct CoachPasscodeGate: View {
    let onUnlock: () -> Void
    let onCancel: () -> Void

    @State private var entry: String = ""
    @State private var shake: CGFloat = 0
    @FocusState private var focused: Bool

    private let maxDigits = 4

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("MF")
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(DS.Colors.Ink.primary)

                Eyebrow(text: "Admin · Coach Access")
                    .padding(.top, DS.Spacing.s12)

                Text("Coach Login")
                    .style(.title1)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s12)

                Text("Enter your coach passcode to access the admin workspace.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, DS.Spacing.s12)

                pinIndicators
                    .padding(.top, DS.Spacing.s40)
                    .offset(x: shake)

                Spacer()

                GhostButton(label: "Cancel", action: onCancel)
                    .padding(.bottom, DS.Spacing.s16)
            }
            .padding(.horizontal, DS.Spacing.s20)

            // Hidden numeric field that drives the passcode.
            TextField("", text: $entry)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.001)
                .frame(width: 1, height: 1)
                .onChange(of: entry) { _, newValue in
                    handleChange(newValue)
                }
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
        // Keep digits only, capped at maxDigits.
        let digits = String(newValue.filter(\.isNumber).prefix(maxDigits))
        if digits != newValue {
            entry = digits
            return
        }
        guard digits.count == maxDigits else { return }

        if digits == coachPasscode {
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
        withAnimation(.spring(response: 0.18, dampingFraction: 0.25)) {
            shake = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.35)) {
                shake = 0
            }
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
