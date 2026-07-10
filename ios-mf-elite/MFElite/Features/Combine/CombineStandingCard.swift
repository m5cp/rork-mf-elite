//
//  CombineStandingCard.swift
//  MFElite
//
//  "Where you stand" — places a combine result on both the boys/men and
//  girls/women benchmark scales for the player's age band. Shows a 5-segment
//  tier bar per scale (Recreational → Pro-Level) with the player's tier filled.
//  When the player's birth year is unset it prompts for it once so the scales
//  can be age-accurate. Results storage is never touched here.
//

import SwiftUI

struct CombineStandingCard: View {
    let test: CombineTest
    /// The value to place on the scales (e.g. the just-saved attempt or the PB).
    /// When nil the card still shows the standard range bands, just without a
    /// highlighted tier — so every test displays the standards before testing.
    let value: Double?

    @State private var profile = PlayerProfileStore.shared
    @State private var pickerYear: Int = Calendar.current.component(.year, from: Date()) - 12

    private let benchmarks = CombineBenchmarks.shared

    /// The 5 ball-skill (technical) tests share one scale for everyone.
    private var isSkillTest: Bool { test.category == "technical" }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Eyebrow(text: "Where You Stand")

                if !benchmarks.hasBenchmark(for: test.id) {
                    Text("No benchmark scale for this test yet.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                } else if let age = profile.age,
                          let band = benchmarks.ageBand(for: age) {
                    content(age: age, bandLabel: band.label)
                } else {
                    birthYearPrompt
                }
            }
        }
    }

    // MARK: - Resolved standing

    @ViewBuilder
    private func content(age: Int, bandLabel: String) -> some View {
        let male = value.flatMap { benchmarks.standing(testID: test.id, value: $0, age: age, female: false) }
        let female = value.flatMap { benchmarks.standing(testID: test.id, value: $0, age: age, female: true) }
        let maleBounds = benchmarks.boundaries(testID: test.id, age: age, female: false)
        let femaleBounds = benchmarks.boundaries(testID: test.id, age: age, female: true)

        Text(bandLabel)
            .style(.foot)
            .foregroundStyle(DS.Colors.Ink.tertiary)

        if let maleBounds {
            scaleRow(title: "Boys / Men", tier: male?.tier, boundaries: maleBounds)
        }
        if let femaleBounds {
            scaleRow(title: "Girls / Women", tier: female?.tier, boundaries: femaleBounds)
        }

        legend

        Text(footnote)
            .style(.micro)
            .foregroundStyle(DS.Colors.Ink.quaternary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, DS.Spacing.s4)
    }

    private var footnote: String {
        let base = "Pro-Level = elite professional standard · Recreational = casual player"
        return isSkillTest ? base + " · Skill scales are the same for everyone." : base
    }

    // MARK: - Scale row

    private func scaleRow(title: String, tier: CombineTier?, boundaries: [Double]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            HStack {
                Text(title)
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                Spacer(minLength: DS.Spacing.s8)
                Text(tier?.label ?? "Not tested")
                    .style(.foot)
                    .foregroundStyle(tier == nil ? DS.Colors.Ink.quaternary : DS.Colors.Ink.primary)
            }

            HStack(spacing: 3) {
                ForEach(CombineTier.allCases, id: \.rawValue) { segment in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fill(for: segment, current: tier))
                        .frame(height: 10)
                        .frame(maxWidth: .infinity)
                }
            }

            Text(rangeCaption(boundaries))
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The numeric tier cutoffs beneath a scale so the range bands are explicit
    /// standards, not just a bar.
    private func rangeCaption(_ boundaries: [Double]) -> String {
        let nums = boundaries.map { CombineFormat.value($0, unit: test.unit) }.joined(separator: " · ")
        return "Tiers at " + nums + " " + test.unit
    }

    /// Fill the bar up to the player's tier: lower segments dim, the current tier
    /// bright (the accent), and segments above unreached. With no value yet every
    /// segment stays neutral so the standards read as an empty scale.
    private func fill(for segment: CombineTier, current: CombineTier?) -> Color {
        guard let current else { return DS.Colors.Bg.raised }
        if segment.rawValue < current.rawValue { return Color.white.opacity(0.34) }
        if segment.rawValue == current.rawValue { return Color.white }
        return DS.Colors.Bg.raised
    }

    private var legend: some View {
        HStack(spacing: 3) {
            ForEach(["Rec", "Club", "Comp", "Elite", "Pro"], id: \.self) { label in
                Text(label)
                    .style(.microSm)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    // MARK: - Birth year prompt

    private var birthYearPrompt: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Text("Add your birth year for accurate scales")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DS.Spacing.s12) {
                Picker("Birth year", selection: $pickerYear) {
                    ForEach(yearRange, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.menu)
                .tint(DS.Colors.Ink.primary)
                .padding(.horizontal, DS.Spacing.s12)
                .padding(.vertical, DS.Spacing.s8)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

                Spacer(minLength: 0)

                PrimaryButton(label: "Save", size: .medium) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    profile.birthYear = pickerYear
                }
            }
        }
    }

    /// Plausible player birth years, newest first.
    private var yearRange: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 60)...(current - 4)).reversed()
    }
}
