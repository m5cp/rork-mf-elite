//
//  ConfirmButton.swift
//  MFElite
//
//  The checkmark "I'm done / that's the one" affordance.
//
//  Apple's own apps put a filled checkmark next to a field or an upload rather
//  than a word like "Save" — it reads instantly, needs no translation, and
//  works at 44pt without crowding a text field. This is that control, in one
//  place, so every text entry and every upload in the app confirms the same way.
//
//  It has three states so the user can see the difference between "there's
//  nothing to confirm yet", "tap this" and "that worked":
//
//    .idle      — dimmed, non-interactive
//    .ready     — solid accent, tappable
//    .confirmed — accent check, briefly, after a successful action
//

import SwiftUI

struct ConfirmButton: View {
    /// False when there is nothing to confirm (empty field, no image chosen).
    var isEnabled: Bool = true
    /// Shows a spinner and blocks taps while an upload or save is in flight.
    var isBusy: Bool = false
    /// Shows the settled checkmark — the change is already saved.
    var isConfirmed: Bool = false
    /// Accessibility label. Defaults to something sensible.
    var label: String = "Confirm"
    let action: () -> Void

    private var isInteractive: Bool { isEnabled && !isBusy && !isConfirmed }

    var body: some View {
        Button {
            guard isInteractive else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(background)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().stroke(
                            isInteractive ? Color.clear : DS.Colors.Line.hairline,
                            lineWidth: 1
                        )
                    )

                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DS.Colors.Ink.primary)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(foreground)
                }
            }
            // 44pt minimum target even though the disc is 40pt.
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isInteractive)
        .animation(DS.Motion.standardSpring, value: isConfirmed)
        .animation(DS.Motion.standardSpring, value: isEnabled)
        .accessibilityLabel(label)
        .accessibilityHint(isConfirmed ? "Saved" : (isEnabled ? "" : "Nothing to confirm yet"))
    }

    private var background: Color {
        if isConfirmed { return DS.Colors.Gold.soft }
        return isInteractive ? DS.Colors.Gold.base : DS.Colors.Bg.raised
    }

    private var foreground: Color {
        if isConfirmed { return DS.Colors.Gold.textLight }
        return isInteractive ? DS.Colors.Gold.inkOnGold : DS.Colors.Ink.disabled
    }
}

/// The same affordance sized for a row trailing edge — used where a full 44pt
/// disc would crowd the layout (media rows, list rows).
struct ConfirmBadge: View {
    var isConfirmed: Bool
    var label: String = "Selected"
    /// What VoiceOver says before the condition is met. The default suits a
    /// picker; beside a half-typed text field "Not selected" is nonsense, so
    /// those call sites pass something that describes the field instead.
    var unconfirmedLabel: String = "Not selected"

    var body: some View {
        HStack(spacing: DS.Spacing.s4) {
            Image(systemName: isConfirmed ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isConfirmed ? DS.Colors.Gold.base : DS.Colors.Ink.disabled)
            if isConfirmed {
                Text(label)
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Gold.textLight)
            }
        }
        .animation(DS.Motion.standardSpring, value: isConfirmed)
        .accessibilityLabel(isConfirmed ? label : unconfirmedLabel)
    }
}

#Preview {
    ZStack {
        DS.Colors.Bg.base.ignoresSafeArea()
        VStack(spacing: DS.Spacing.s24) {
            HStack(spacing: DS.Spacing.s16) {
                ConfirmButton(isEnabled: false) {}
                ConfirmButton {}
                ConfirmButton(isBusy: true) {}
                ConfirmButton(isConfirmed: true) {}
            }
            HStack(spacing: DS.Spacing.s16) {
                ConfirmBadge(isConfirmed: false)
                ConfirmBadge(isConfirmed: true)
            }
        }
    }
}
