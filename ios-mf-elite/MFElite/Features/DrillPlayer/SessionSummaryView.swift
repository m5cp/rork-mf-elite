//
//  SessionSummaryView.swift
//  MFElite
//
//  End-of-session recap shown after the final drill of a queue is logged.
//

import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    let queue: TrainingQueue
    var onDone: () -> Void

    @Query private var players: [PlayerState]
    @State private var reveal = false

    private var totalMinutes: Int {
        let secs = queue.completed.reduce(0) { $0 + $1.durationSec }
        return max(1, Int((Double(secs) / 60).rounded()))
    }

    private var totalXP: Int {
        queue.completed.reduce(0) { $0 + $1.xp }
    }

    private var streak: Int { players.first?.streak ?? 0 }

    private var headline: String {
        switch queue.source {
        case .routine: return "Routine complete"
        case .workout: return "Workout complete"
        case .single:  return "Session complete"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 92, height: 92)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                    )
                    .scaleEffect(reveal ? 1 : 0)
                    .padding(.top, DS.Spacing.s64)

                Eyebrow(text: headline.uppercased())
                    .padding(.top, DS.Spacing.s24)

                if let name = queue.sourceName {
                    Text(name)
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .multilineTextAlignment(.center)
                        .padding(.top, DS.Spacing.s8)
                } else {
                    Text("Well trained.")
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(.top, DS.Spacing.s8)
                }

                statsRow
                    .padding(.top, DS.Spacing.s32)

                drillList
                    .padding(.top, DS.Spacing.s24)

                PrimaryButton(label: "Done") { onDone() }
                    .padding(.top, DS.Spacing.s32)
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Colors.Bg.base)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(DS.Motion.celebrationSpring) { reveal = true }
        }
    }

    private var statsRow: some View {
        HStack(spacing: DS.Spacing.s12) {
            summaryTile(value: "\(queue.completed.count)", label: "Drills")
            summaryTile(value: "\(totalMinutes)", label: "Minutes")
            summaryTile(value: "+\(totalXP)", label: "XP")
            summaryTile(value: "\(streak)", label: "Streak")
        }
    }

    private func summaryTile(value: String, label: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 24))
                .tracking(-0.6)
                .foregroundStyle(DS.Colors.Ink.primary)
            Eyebrow(text: label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s16)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var drillList: some View {
        VStack(spacing: 0) {
            ForEach(Array(queue.completed.enumerated()), id: \.element.id) { idx, item in
                HStack(spacing: DS.Spacing.s12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                    DisciplineMark(kind: item.disciplineMark, size: 14)
                    Text(item.title)
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, DS.Spacing.s12)

                if idx != queue.completed.count - 1 {
                    Hairline()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s16)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}
