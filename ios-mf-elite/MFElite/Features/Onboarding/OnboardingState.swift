//
//  OnboardingState.swift
//  MFElite
//
//  Local, transient state captured across the onboarding sequence. Persisted
//  to PlayerProfileStore + Supabase only on completion.
//

import SwiftUI
import Observation

enum OnboardingStep: Int, CaseIterable {
    case splash
    case identify
    case username
    case position
    case pledge
    case number
    case passport
}

@Observable
@MainActor
final class OnboardingState {
    var step: OnboardingStep = .splash

    var inviteCode: String = ""
    var playerName: String = ""
    var username: String = ""
    var position: String = ""
    var kitNumber: String = "10"

    /// True when the player arrived via a coach invite code (vs. open self-signup).
    var hasInvite: Bool { ProfileValidation.isInviteCodeValid(inviteCode) }

    /// Derived initials for the passport monogram.
    var initials: String {
        let parts = playerName
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        guard let first = parts.first?.first else { return "P1" }
        if parts.count >= 2, let second = parts[1].first {
            return "\(first)\(second)".uppercased()
        }
        return String(first).uppercased()
    }

    func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(DS.Motion.standardSpring) { step = next }
    }
}
