//
//  KeyboardWarmup.swift
//  MFElite
//
//  Suppresses the one-time iOS "Slide to Type" (QuickPath) tutorial coachmark
//  that otherwise interrupts the first time the keyboard opens during
//  onboarding. We briefly present an off-screen text field at launch so the
//  system consumes the tutorial before the player ever reaches a real input.
//

import UIKit

enum KeyboardWarmup {
    private static var hasRun = false

    /// Call once early in the app lifecycle.
    static func run() {
        guard !hasRun else { return }
        hasRun = true

        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first
            else { return }

            let field = UITextField(frame: .zero)
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.isHidden = true
            window.addSubview(field)

            field.becomeFirstResponder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                field.resignFirstResponder()
                field.removeFromSuperview()
            }
        }
    }
}
