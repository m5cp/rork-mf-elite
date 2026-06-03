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
    case code
    case signIn
    case identify
    case position
    case pledge
    case number
    case passport

    /// Total filled segments for the StepBar (players see 7 chapters; splash excluded).
    static let stepTotal = 7

    /// 1-of-7 progress index for the StepBar (splash excluded).
    var stepIndex: Int {
        switch self {
        case .splash:   return 0
        case .code:     return 1
        case .signIn:   return 2
        case .identify: return 3
        case .position: return 4
        case .pledge:   return 5
        case .number:   return 6
        case .passport: return 7
        }
    }
}

/// The academy pledge tiers, in ascending intensity.
enum PledgeTier: String, CaseIterable, Identifiable {
    case recovery
    case standard
    case elite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recovery: return "Recovery"
        case .standard: return "Standard"
        case .elite:    return "Elite"
        }
    }

    var meta: String {
        switch self {
        case .recovery: return "2 / week · 25 min"
        case .standard: return "4 / week · 35 min"
        case .elite:    return "6 / week · 45 min"
        }
    }

    var quote: String {
        switch self {
        case .recovery: return "I will keep moving. I will come back stronger than I left."
        case .standard: return "I will train. I will compete. I will close the gap."
        case .elite:    return "I will outwork the room. Every session. No exceptions."
        }
    }
}

/// A pitch position with its code and on-pitch coordinates (0–1 space).
struct PitchPosition: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let name: String
    /// Normalized x/y on the pitch (0,0 top-left → 1,1 bottom-right).
    let x: CGFloat
    let y: CGFloat

    static let all: [PitchPosition] = [
        PitchPosition(code: "ST", name: "Striker", x: 0.50, y: 0.14),
        PitchPosition(code: "LW", name: "Left Winger", x: 0.32, y: 0.28),
        PitchPosition(code: "RW", name: "Right Winger", x: 0.68, y: 0.28),
        PitchPosition(code: "CAM", name: "Attacking Mid", x: 0.50, y: 0.44),
        PitchPosition(code: "CM", name: "Centre Mid", x: 0.32, y: 0.56),
        PitchPosition(code: "CM2", name: "Centre Mid", x: 0.68, y: 0.56),
        PitchPosition(code: "LB", name: "Left Back", x: 0.22, y: 0.74),
        PitchPosition(code: "CB", name: "Centre Back", x: 0.50, y: 0.74),
        PitchPosition(code: "RB", name: "Right Back", x: 0.78, y: 0.74),
        PitchPosition(code: "GK", name: "Goalkeeper", x: 0.50, y: 0.92)
    ]
}

@Observable
@MainActor
final class OnboardingState {
    var step: OnboardingStep = .splash

    var playerName: String = ""
    var classYear: Int = OnboardingState.defaultClassYear
    var selectedPosition: PitchPosition? = nil
    var foot: String = "Right"
    var pledgeTier: PledgeTier = .standard
    var kitNumber: String = ""

    /// Member number issued on the passport — a stable random 4-digit ID.
    let memberNumber: Int = Int.random(in: 1000...9999)

    /// Coach is fixed for the academy.
    static let coachName = "Coach Matteo Finazzi"

    /// Defaults to the upcoming graduation year (next year after July).
    static var defaultClassYear: Int {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        return month >= 7 ? year + 4 : year + 3
    }

    var positionName: String { selectedPosition?.name ?? skippedPositionName ?? "Anywhere" }
    var positionCode: String { selectedPosition?.code.replacingOccurrences(of: "2", with: "") ?? "—" }

    /// Derived initials for the monogram / passport.
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

    /// Auto-generated unique-ish handle (the design flow has no username step).
    var generatedUsername: String {
        let base = playerName
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        let trimmed = base.isEmpty ? "player" : String(base.prefix(12))
        return "\(trimmed)\(memberNumber)"
    }

    func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(DS.Motion.standardSpring) { step = next }
    }

    /// Fill any details the player hasn't supplied with sensible defaults so a
    /// skipped onboarding still produces a complete, editable profile.
    func applySkipDefaults() {
        if playerName.trimmingCharacters(in: .whitespaces).isEmpty {
            playerName = "Player"
        }
        if selectedPosition == nil {
            skippedPositionName = "Midfielder"
        }
        if kitNumber.isEmpty {
            kitNumber = "00"
        }
        // pledgeTier defaults to .standard and foot defaults to "Right".
    }

    /// Position name override used only when onboarding is skipped without a
    /// pitch selection.
    private var skippedPositionName: String? = nil
}
