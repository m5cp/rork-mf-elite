//
//  SessionOverviewSheet.swift
//  MFElite
//
//  A read-only overview of the full drill lineup for the running session,
//  opened by tapping the "Drill X of Y" counter in the player. Completed
//  drills are checked, the current drill is highlighted, the rest upcoming.
//

import SwiftUI

struct SessionOverviewSheet: View {
    let queue: TrainingQueue

    @Environment(\.dismiss) private var dismiss

    private var titleText: String {
        if let name = queue.sourceName, !name.isEmpty { return name }
        return queue.source == .workout ? "Workout" : "Session"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        Eyebrow(text: "Session Overview")
                        Text(titleText)
                            .style(.title2)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Drill \(queue.position) of \(queue.count)")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                    Spacer(minLength: DS.Spacing.s8)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .frame(width: 32, height: 32)
                            .background(DS.Colors.Bg.raised)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Close overview")
                }
                .padding(.top, DS.Spacing.s24)

                VStack(spacing: 0) {
                    ForEach(Array(queue.items.enumerated()), id: \.offset) { idx, item in
                        drillRow(idx: idx, item: item)
                        if idx != queue.items.count - 1 {
                            Hairline()
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.s8)
                .padding(.horizontal, DS.Spacing.s12)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .padding(.top, DS.Spacing.s20)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s32)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .presentationBackground(DS.Colors.Bg.base)
        .preferredColorScheme(.dark)
    }

    /// One drill in the lineup: done (checked), current (highlighted), or upcoming.
    @ViewBuilder
    private func drillRow(idx: Int, item: DrillContext) -> some View {
        let isDone = idx < queue.currentIndex
        let isCurrent = idx == queue.currentIndex
        HStack(spacing: DS.Spacing.s12) {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 18, alignment: .leading)
            } else if isCurrent {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 18, alignment: .leading)
            } else {
                Text("\(idx + 1)")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .frame(width: 18, alignment: .leading)
            }

            DisciplineMark(kind: item.discipline.mark, size: 14)

            Text(item.drill.title)
                .style(.callout)
                .fontWeight(isCurrent ? .bold : .regular)
                .foregroundStyle(isCurrent ? DS.Colors.Ink.primary : (isDone ? DS.Colors.Ink.tertiary : DS.Colors.Ink.secondary))
                .strikethrough(isDone, color: DS.Colors.Ink.quaternary)

            Spacer(minLength: 0)

            if isCurrent {
                Text("NOW")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white, in: Capsule())
            }
        }
        .padding(.vertical, DS.Spacing.s8 + 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(idx + 1). \(item.drill.title)")
        .accessibilityValue(isDone ? "Completed" : (isCurrent ? "Current drill" : "Upcoming"))
    }
}
