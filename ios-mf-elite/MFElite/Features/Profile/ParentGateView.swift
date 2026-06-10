//
//  ParentGateView.swift
//  MFElite
//
//  The passcode sheet for the parental gate. Two modes:
//   - .set: the parent creates a passcode (enter, then confirm).
//   - .verify: a passcode is required to proceed with a protected action.
//
//  Uses a custom numeric keypad so the experience reads as a lock rather than a
//  text field, matching the app's dark, premium styling.
//

import SwiftUI

enum ParentGateMode: Identifiable {
    case set
    case verify(title: String, onSuccess: () -> Void)

    var id: String {
        switch self {
        case .set: return "set"
        case .verify: return "verify"
        }
    }
}

struct ParentGateView: View {
    let mode: ParentGateMode
    @Environment(\.dismiss) private var dismiss

    @State private var gate = ParentGate.shared

    /// Digits entered so far in the current step.
    @State private var entry: String = ""
    /// The first entry while creating a passcode, awaiting confirmation.
    @State private var firstEntry: String = ""
    @State private var confirming = false
    @State private var errorText: String?
    @State private var shake = false

    private let length = ParentGate.pinLength
    private let errorColor = Color(hex: "#FF5A5A")

    var body: some View {
        VStack(spacing: DS.Spacing.s24) {
            grabber
            header
            dots
            if let errorText {
                Text(errorText)
                    .style(.foot)
                    .foregroundStyle(errorColor)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            keypad
            Button("Cancel") { dismiss() }
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .padding(.bottom, DS.Spacing.s8)
        }
        .padding(.horizontal, DS.Spacing.s24)
        .padding(.top, DS.Spacing.s12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.Bg.base)
    }

    // MARK: - Header

    private var grabber: some View {
        Capsule()
            .fill(DS.Colors.Line.subtle)
            .frame(width: 36, height: 5)
    }

    private var header: some View {
        VStack(spacing: DS.Spacing.s8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.primary)
            Text(title)
                .style(.title2)
                .foregroundStyle(DS.Colors.Ink.primary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var title: String {
        switch mode {
        case .set:
            return confirming ? "Confirm passcode" : "Create a passcode"
        case .verify(let title, _):
            return title
        }
    }

    private var subtitle: String {
        switch mode {
        case .set:
            return confirming
                ? "Re-enter the 4-digit passcode to confirm."
                : "Set a 4-digit passcode only a parent knows. It locks purchases and family settings."
        case .verify:
            return "Enter your parent passcode to continue."
        }
    }

    // MARK: - Dots

    private var dots: some View {
        HStack(spacing: DS.Spacing.s16) {
            ForEach(0..<length, id: \.self) { index in
                Circle()
                    .fill(index < entry.count ? DS.Colors.Ink.primary : Color.clear)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle().stroke(DS.Colors.Line.strong, lineWidth: 1.5)
                    )
            }
        }
        .offset(x: shake ? -8 : 0)
        .animation(shake ? .default.repeatCount(3, autoreverses: true).speed(6) : .default, value: shake)
    }

    // MARK: - Keypad

    private var keypad: some View {
        VStack(spacing: DS.Spacing.s16) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: DS.Spacing.s16) {
                    ForEach(1..<4, id: \.self) { col in
                        let digit = row * 3 + col
                        keyButton("\(digit)")
                    }
                }
            }
            HStack(spacing: DS.Spacing.s16) {
                Color.clear.frame(width: 72, height: 72)
                keyButton("0")
                deleteButton
            }
        }
    }

    private func keyButton(_ value: String) -> some View {
        Button {
            append(value)
        } label: {
            Text(value)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(width: 72, height: 72)
                .background(DS.Colors.Bg.card)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Digit \(value)")
    }

    private var deleteButton: some View {
        Button {
            deleteLast()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DS.Colors.Ink.secondary)
                .frame(width: 72, height: 72)
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Delete")
        .opacity(entry.isEmpty ? 0.3 : 1)
        .disabled(entry.isEmpty)
    }

    // MARK: - Entry logic

    private func append(_ value: String) {
        guard entry.count < length else { return }
        errorText = nil
        entry += value
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if entry.count == length {
            // Let the final dot render before resolving.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                resolve()
            }
        }
    }

    private func deleteLast() {
        guard !entry.isEmpty else { return }
        entry.removeLast()
    }

    private func resolve() {
        switch mode {
        case .set:
            if confirming {
                if entry == firstEntry {
                    gate.setPIN(entry)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } else {
                    fail("Passcodes didn't match. Start again.")
                    confirming = false
                    firstEntry = ""
                }
            } else {
                firstEntry = entry
                entry = ""
                confirming = true
            }
        case .verify(_, let onSuccess):
            if gate.verify(entry) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSuccess()
                dismiss()
            } else {
                fail("Incorrect passcode.")
            }
        }
    }

    private func fail(_ message: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        withAnimation { errorText = message }
        entry = ""
        shake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
    }
}

#Preview("Set") {
    Color.black.sheet(isPresented: .constant(true)) {
        ParentGateView(mode: .set)
            .preferredColorScheme(.dark)
    }
}
