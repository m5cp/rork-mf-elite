//
//  KeyboardToolbar.swift
//  MFElite
//
//  A shared keyboard accessory that gives every text input a "Done" (checkmark)
//  button so the keyboard can always be dismissed. Attach once per screen and
//  pass a closure that clears the relevant @FocusState.
//

import SwiftUI

extension View {
    /// Adds a trailing checkmark button to the keyboard accessory bar that
    /// dismisses the keyboard via the supplied closure (typically clearing a
    /// `@FocusState`). Attach to a single container per screen to avoid
    /// duplicate toolbar items.
    func keyboardDoneButton(_ dismiss: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                }
                .tint(DS.Colors.Ink.primary)
                .accessibilityLabel("Done")
            }
        }
    }
}
