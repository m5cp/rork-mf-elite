//
//  WeeklyHealthStats.swift
//  MFElite
//
//  A tiny cache of this week's HealthKit totals (steps, miles) so the
//  synchronous share-card builder can include them. Refreshed by the share
//  gallery before cards are built. Values are nil until a successful fetch.
//

import Foundation

@MainActor
final class WeeklyHealthStats {
    static let shared = WeeklyHealthStats()
    private init() {}

    private(set) var weekSteps: Int?
    private(set) var weekMiles: Double?

    func refresh() async {
        let steps = await HealthKitService.shared.fetchWeekSteps()
        let miles = await HealthKitService.shared.fetchWeekMiles()
        // Treat 0 as "unknown" — HealthKit returns 0 for both "denied" and
        // "no data", and printing a false 0 on a share card reads as a lie.
        weekSteps = steps > 0 ? steps : nil
        weekMiles = miles > 0.05 ? miles : nil
    }
}
