//
//  BirthYearField.swift
//  MFElite
//
//  One control for "year of birth".
//
//  It was previously built four different ways for the same field:
//    • Settings          — .wheel over 58 years
//    • Onboarding        — .wheel over 96 years
//    • Edit Profile      — .menu over 58 years
//    • Combine standing  — .menu over 57 years
//
//  A wheel over 58–96 items shows about four at a time and takes a long drag
//  to cross a decade; a flat menu that long is a full-screen scrolling popover.
//  This narrows by decade first, so any year is two taps away, and it keeps one
//  range and one label everywhere.
//

import SwiftUI

struct BirthYearField: View {
    @Binding var year: Int

    /// Youngest age offered. Onboarding and Settings both want 4.
    var minimumAge: Int = 4
    /// Oldest age offered. 60 covers players, parents and coaches.
    var maximumAge: Int = 60
    /// Shown as the unset option. Pass nil to require a value.
    var unsetLabel: String? = "Not set"

    @State private var decade: Int?

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var newest: Int { currentYear - minimumAge }
    private var oldest: Int { currentYear - maximumAge }

    /// Decade buckets present in the range, newest first.
    private var decades: [Int] {
        let start = (oldest / 10) * 10
        let end = (newest / 10) * 10
        return stride(from: end, through: start, by: -10).map { $0 }
    }

    private func years(in decade: Int) -> [Int] {
        Array(max(oldest, decade)...min(newest, decade + 9)).reversed()
    }

    /// The decade to show as selected — the chosen year's, or the last tapped.
    private var activeDecade: Int? {
        if year > 0 { return (year / 10) * 10 }
        return decade
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            decadeRow

            if let activeDecade {
                yearGrid(for: activeDecade)
            }

            if let unsetLabel, year != 0 {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(DS.Motion.standardSpring) {
                        year = 0
                        decade = nil
                    }
                } label: {
                    Text(unsetLabel)
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
                .padding(.top, DS.Spacing.s4)
            }
        }
    }

    private var decadeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s8) {
                ForEach(decades, id: \.self) { value in
                    chip(
                        label: "\(value)s",
                        selected: activeDecade == value
                    ) {
                        decade = value
                        // Clear a year from another decade so the grid and the
                        // selected chip can't disagree.
                        if year > 0, (year / 10) * 10 != value { year = 0 }
                    }
                }
            }
        }
    }

    private func yearGrid(for decade: Int) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.s8), count: 5)
        return LazyVGrid(columns: columns, spacing: DS.Spacing.s8) {
            ForEach(years(in: decade), id: \.self) { value in
                chip(label: String(value), selected: year == value) {
                    year = value
                }
            }
        }
    }

    private func chip(
        label: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(DS.Motion.standardSpring) { action() }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(selected ? Color.white : DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

#Preview {
    struct Harness: View {
        @State private var year = 0
        var body: some View {
            ZStack {
                DS.Colors.Bg.base.ignoresSafeArea()
                BirthYearField(year: $year)
                    .padding()
            }
        }
    }
    return Harness()
}
