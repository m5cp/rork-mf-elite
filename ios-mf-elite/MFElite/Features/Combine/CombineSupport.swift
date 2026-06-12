//
//  CombineSupport.swift
//  MFElite
//
//  Shared logic for the MF Combine: personal-best resolution (respecting
//  lowerIsBetter), value/unit formatting, delta direction, and whole-combine
//  completion detection. Pure functions over the append-only CombineResult log.
//

import Foundation
import SwiftUI

/// Which direction a change moved relative to the previous attempt.
enum CombineDelta {
    case improved
    case same
    case declined

    var tint: Color {
        switch self {
        case .improved: return Color(hex: "#3DD68C")
        case .same:     return DS.Colors.Ink.quaternary
        case .declined: return Color(hex: "#FF5A5F")
        }
    }
}

enum CombineStats {

    /// Best recorded value for a test, honoring `lowerIsBetter` (lowest time wins
    /// for timed events; highest count wins otherwise). `nil` when no results.
    static func personalBest(_ test: CombineTest, results: [CombineResult]) -> Double? {
        let values = results.filter { $0.testID == test.id }.map(\.value)
        guard !values.isEmpty else { return nil }
        return test.lowerIsBetter ? values.min() : values.max()
    }

    /// The most recent result for a test, or `nil` when none exist.
    static func latest(_ testID: String, results: [CombineResult]) -> CombineResult? {
        results
            .filter { $0.testID == testID }
            .max(by: { $0.recordedAt < $1.recordedAt })
    }

    /// Whether `value` would set a new personal best given the prior results
    /// (which must NOT include the new attempt). True only when it strictly beats
    /// the existing best; the very first attempt also counts as a PB.
    static func isPersonalBest(_ value: Double, test: CombineTest, priorResults: [CombineResult]) -> Bool {
        guard let best = personalBest(test, results: priorResults) else { return true }
        return test.lowerIsBetter ? value < best : value > best
    }

    /// Direction of `value` versus a `previous` value for a given test.
    static func delta(_ value: Double, previous: Double, test: CombineTest) -> CombineDelta {
        if value == previous { return .same }
        let isUp = value > previous
        // For timed events a smaller number is an improvement.
        let improved = test.lowerIsBetter ? !isUp : isUp
        return improved ? .improved : .declined
    }

    /// True when every test has at least one result recorded on `day`.
    static func combineComplete(tests: [CombineTest], results: [CombineResult], on day: Date = Date()) -> Bool {
        guard !tests.isEmpty else { return false }
        let calendar = Calendar.current
        let testedToday = Set(
            results
                .filter { calendar.isDate($0.recordedAt, inSameDayAs: day) }
                .map(\.testID)
        )
        return tests.allSatisfy { testedToday.contains($0.id) }
    }

    /// The single most recent moment any result was recorded, across all tests.
    static func lastCombineDate(_ results: [CombineResult]) -> Date? {
        results.map(\.recordedAt).max()
    }
}

enum CombineFormat {

    /// A score formatted for display — two decimals for timed events, whole
    /// numbers otherwise (with a single decimal preserved for half-laps).
    static func value(_ value: Double, unit: String) -> String {
        if unit == "seconds" {
            return String(format: "%.2f", value)
        }
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    /// Value plus its unit, e.g. "9.43 seconds" or "42 touches".
    static func valueWithUnit(_ value: Double, unit: String) -> String {
        "\(self.value(value, unit: unit)) \(unit)"
    }

    /// A short relative phrase like "2 days ago".
    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
