//
//  BiometricLock.swift
//  MFElite
//
//  Thin wrapper around LocalAuthentication for the optional Coach Mode lock.
//  Uses Face ID / Touch ID with automatic passcode fallback, so a shared phone
//  can protect rostered players' data behind the owner's biometrics.
//

import Foundation
import LocalAuthentication

@MainActor
enum BiometricLock {
    /// True when the device can authenticate the owner (biometrics or passcode).
    static var isAvailable: Bool {
        var error: NSError?
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Human label for the enrolled biometric ("Face ID" / "Touch ID"), or "passcode".
    static var biometryLabel: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "passcode"
        }
    }

    /// Prompt the owner to authenticate. Falls back to the device passcode.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
