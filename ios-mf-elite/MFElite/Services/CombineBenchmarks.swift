//
//  CombineBenchmarks.swift
//  MFElite
//
//  Decodes the bundled `combine-benchmarks.json` age/sex performance scales and
//  resolves a player's standing for a given test result. Each test exposes 4
//  ascending difficulty cut points per (sex, age band) that separate the 5 tiers
//  Recreational → Club → Competitive → Elite → Pro-Level. For timed events a
//  FASTER (smaller) time lands in a BETTER tier (encoded via lowerIsBetter).
//
//  Numbers come from published research norms for the physical events (20m
//  sprint, pro-agility, standing broad jump) adjusted to these protocols; the 5
//  ball-skill tests have no official norms anywhere and use MF Elite standards
//  built from common juggling benchmarks and coaching experience.
//

import Foundation

/// The five performance tiers, ordered from casual to elite professional.
enum CombineTier: Int, CaseIterable {
    case recreational = 0, club, competitive, elite, proLevel

    var label: String {
        ["Recreational", "Club", "Competitive", "Elite", "Pro-Level"][rawValue]
    }
}

/// Loads and queries the bundled combine benchmark tables.
struct CombineBenchmarks {

    /// An age bracket from the benchmark file (e.g. "U14" → ages up to 13).
    struct AgeBand: Decodable {
        let id: String
        let label: String
        let maxAge: Int
    }

    private struct TestBenchmark: Decodable {
        let lowerIsBetter: Bool
        let male: [String: [Double]]
        let female: [String: [Double]]
    }

    private struct Root: Decodable {
        let tiers: [String]
        let ageBands: [AgeBand]
        let tests: [String: TestBenchmark]
    }

    /// One scale's resolved standing: the tier plus the band it was measured in.
    struct Standing {
        let tier: CombineTier
        let band: AgeBand
    }

    static let shared = CombineBenchmarks()

    private let root: Root?

    private init() {
        if let url = Bundle.main.url(forResource: "combine-benchmarks", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(Root.self, from: data) {
            root = decoded
        } else {
            assertionFailure("combine-benchmarks.json missing or failed to decode")
            root = nil
        }
    }

    /// Whether a benchmark table exists for the given test id.
    func hasBenchmark(for testID: String) -> Bool {
        root?.tests[testID] != nil
    }

    /// The age band for a player's age: the first band whose `maxAge >= age`,
    /// falling back to the final (Adult / Pro) band.
    func ageBand(for age: Int) -> AgeBand? {
        guard let root else { return nil }
        return root.ageBands.first(where: { age <= $0.maxAge }) ?? root.ageBands.last
    }

    /// Resolve the standing for a `value` on a given scale (male/female) for a
    /// test and player age. `nil` when the test or band has no benchmark data.
    func standing(testID: String, value: Double, age: Int, female: Bool) -> Standing? {
        guard let root,
              let test = root.tests[testID],
              let band = ageBand(for: age) else { return nil }
        let table = female ? test.female : test.male
        guard let boundaries = table[band.id], boundaries.count == 4 else { return nil }
        let tier = Self.tier(value: value, boundaries: boundaries, lowerIsBetter: test.lowerIsBetter)
        return Standing(tier: tier, band: band)
    }

    /// Map a raw value to a tier given the 4 ascending difficulty cut points.
    ///
    /// higher-is-better: value >= boundaries[3] → proLevel, >= [2] → elite,
    /// >= [1] → competitive, >= [0] → club, else recreational.
    /// lower-is-better (timed events — a FASTER/SMALLER time is BETTER):
    /// value <= boundaries[3] → proLevel, <= [2] → elite, <= [1] → competitive,
    /// <= [0] → club, else recreational.
    static func tier(value: Double, boundaries: [Double], lowerIsBetter: Bool) -> CombineTier {
        if lowerIsBetter {
            if value <= boundaries[3] { return .proLevel }
            if value <= boundaries[2] { return .elite }
            if value <= boundaries[1] { return .competitive }
            if value <= boundaries[0] { return .club }
            return .recreational
        } else {
            if value >= boundaries[3] { return .proLevel }
            if value >= boundaries[2] { return .elite }
            if value >= boundaries[1] { return .competitive }
            if value >= boundaries[0] { return .club }
            return .recreational
        }
    }
}
