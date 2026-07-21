//
//  TrackingConsent.swift
//  MFElite
//
//  Requests App Tracking Transparency only for adult users. Youth athletes are
//  never shown the prompt (age < 18 or unknown age is treated as youth-safe).
//  Called once per launch after the main UI appears.
//

import Foundation
import AppTrackingTransparency

@MainActor
enum TrackingConsent {
    private static var requestedThisLaunch = false

    /// Ask for tracking permission once, and only when the signed-in user is a
    /// known adult. Silently skips for youth or unknown ages.
    static func requestIfAdult() {
        guard !requestedThisLaunch else { return }
        requestedThisLaunch = true

        guard let age = PlayerProfileStore.shared.age, age >= 18 else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }

        // Small delay so the prompt doesn't collide with launch presentation.
        Task {
            try? await Task.sleep(for: .seconds(1))
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }
}
