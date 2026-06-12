//
//  QuickTrainSheet.swift
//  MFElite
//
//  The duration picker for Quick Train: pick 5, 10 or 20 minutes and we assemble
//  a time-boxed session that fits and fills today's goals.
//

import SwiftUI

struct QuickTrainSheet: View {
    /// Called with the chosen budget in minutes.
    let onSelect: (Int) -> Void

    private struct Option: Identifiable {
        let minutes: Int
        let title: String
        let subtitle: String
        var id: Int { minutes }
    }

    private let options: [Option] = [
        Option(minutes: 5, title: "Quick sharpener", subtitle: "One or two focused drills"),
        Option(minutes: 10, title: "Solid touch session", subtitle: "A balanced few drills"),
        Option(minutes: 20, title: "Full mini-workout", subtitle: "A proper chained session")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Quick Train")
                    Text("How long have you got?")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("We'll build a session that fits your time and fills today's goals.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, DS.Spacing.s24)

                VStack(spacing: DS.Spacing.s12) {
                    ForEach(options) { option in
                        optionRow(option)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s32)
        }
        .scrollIndicators(.hidden)
    }

    private func optionRow(_ option: Option) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onSelect(option.minutes)
        } label: {
            HStack(spacing: DS.Spacing.s16) {
                VStack(spacing: 0) {
                    Text("\(option.minutes)")
                        .font(DS.Typography.num(size: 30))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("MIN")
                        .style(.microSm)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                .frame(width: 64, height: 64)
                .background(DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text(option.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(option.subtitle)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(DS.Spacing.s16)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint("Start a \(option.minutes) minute session")
    }
}
