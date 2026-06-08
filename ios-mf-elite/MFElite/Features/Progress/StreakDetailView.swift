//
//  StreakDetailView.swift
//  MFElite
//
//  The retention engine: streak count, freezes, activity grid, and milestones.
//

import SwiftUI
import SwiftData

/// Navigation route to the streak dashboard.
struct StreakRoute: Hashable {}

struct StreakDetailView: View {
    @Query private var players: [PlayerState]
    @Environment(SubscriptionService.self) private var subscription

    private var viewModel: StreakDetailViewModel {
        let player = players.first
        return StreakDetailViewModel(
            streak: player?.streak ?? 0,
            freezesRemaining: player?.freezesRemaining ?? 0,
            lastTrainedDate: player?.lastTrainedDate
        )
    }

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(vm)
                todayPill(vm)
                upgradePrompt(vm)
                freezeCard(vm)
                activityGrid(vm)
                milestoneLadder(vm)
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 1. Hero count

    private func hero(_ vm: StreakDetailViewModel) -> some View {
        VStack(spacing: 0) {
            Text("\(vm.streak)")
                .font(.system(size: 132, weight: .heavy).monospacedDigit())
                .foregroundStyle(DS.Colors.Ink.primary)
                .tracking(-4)

            Text("day streak")
                .style(.title2)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .padding(.top, DS.Spacing.s4)

            Text("Train every day to keep your streak alive. Miss a day and it resets — unless you have a freeze.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.top, DS.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.s48)
    }

    // MARK: - 2. Today status pill

    private func todayPill(_ vm: StreakDetailViewModel) -> some View {
        Group {
            if vm.trainedToday {
                HStack(spacing: DS.Spacing.s4 + 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("Today Logged · Counted")
                        .style(.foot)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(DS.Colors.Ground.primary)
                .padding(.vertical, DS.Spacing.s8)
                .padding(.horizontal, DS.Spacing.s20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            } else {
                Text("Not Yet Trained")
                    .style(.foot)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.vertical, DS.Spacing.s8)
                    .padding(.horizontal, DS.Spacing.s20)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.pill)
                            .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - 2b. Upgrade prompt

    @ViewBuilder
    private func upgradePrompt(_ vm: StreakDetailViewModel) -> some View {
        if vm.streak >= 7 && !subscription.hasFullAccess {
            Card(raised: true) {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Keep It Going")
                    Text("Your discipline deserves Elite access")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text("Unlock every level, certifications, and streak freezes to protect your run.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                    PrimaryButton(label: "Unlock Elite", size: .medium) {
                        subscription.presentPaywall()
                    }
                    .padding(.top, DS.Spacing.s4)
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24 + 4)
        }
    }

    // MARK: - 3. Freeze tokens

    private func freezeCard(_ vm: StreakDetailViewModel) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Streak Freezes")

                HStack(spacing: DS.Spacing.s8 + 2) {
                    ForEach(0..<vm.freezeTotal, id: \.self) { index in
                        let filled = index < vm.freezesRemaining
                        Circle()
                            .fill(filled ? Color.white : Color.clear)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle().stroke(filled ? Color.clear : DS.Colors.Line.subtle, lineWidth: 1)
                            )
                            .overlay {
                                Image(systemName: "snowflake")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(filled ? DS.Colors.Ground.primary : DS.Colors.Ink.disabled)
                            }
                    }
                }
                .padding(.top, DS.Spacing.s12)

                Text("Auto-protects one missed day · earned at 7-day, 30-day, and 50-day milestones")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .padding(.top, DS.Spacing.s12 - 2)

                Eyebrow(text: "\(vm.freezesRemaining) Of \(vm.freezeTotal) Remaining")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, DS.Spacing.s8)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    // MARK: - 4. Activity grid

    private func activityGrid(_ vm: StreakDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Activity · Last 5 Weeks")

            HStack(spacing: 6) {
                ForEach(Array(vm.weekdayInitials.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .style(.microSm)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, DS.Spacing.s12)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(vm.activityDays) { day in
                    dayCell(day)
                }
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    @ViewBuilder
    private func dayCell(_ day: ActivityDay) -> some View {
        switch day.state {
        case .trained:
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(height: 28)
        case .notTrained:
            RoundedRectangle(cornerRadius: 6)
                .fill(DS.Colors.Bg.raised)
                .frame(height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                )
        case .future:
            RoundedRectangle(cornerRadius: 6)
                .fill(DS.Colors.Bg.raised.opacity(0.5))
                .frame(height: 28)
        case .todayPending:
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .frame(height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            DS.Colors.Line.strong,
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                        )
                )
        }
    }

    // MARK: - 5. Milestone ladder

    private func milestoneLadder(_ vm: StreakDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Milestones")

            VStack(spacing: 0) {
                let items = vm.milestones
                ForEach(Array(items.enumerated()), id: \.element.id) { index, milestone in
                    milestoneRow(milestone, isLast: index == items.count - 1)
                }
            }
            .padding(.top, DS.Spacing.s12)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24 + 4)
    }

    private func milestoneRow(_ milestone: MilestoneState, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.s16) {
                milestoneIcon(milestone)

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Text(milestone.name)
                        .style(.title3)
                        .foregroundStyle(milestone.achieved || milestone.isCurrentTarget
                            ? DS.Colors.Ink.primary : DS.Colors.Ink.tertiary)
                    milestoneStatus(milestone)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, DS.Spacing.s12 + 2)

            if !isLast {
                Hairline()
            }
        }
    }

    @ViewBuilder
    private func milestoneIcon(_ milestone: MilestoneState) -> some View {
        if milestone.achieved {
            Circle()
                .fill(Color.white)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                )
        } else if milestone.isCurrentTarget {
            Circle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: 36, height: 36)
                .overlay(
                    Text("\(milestone.days)")
                        .style(.num(size: 13))
                        .foregroundStyle(DS.Colors.Ink.primary)
                )
        } else {
            Circle()
                .stroke(DS.Colors.Line.subtle, lineWidth: 1)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.disabled)
                )
        }
    }

    @ViewBuilder
    private func milestoneStatus(_ milestone: MilestoneState) -> some View {
        if milestone.achieved {
            HStack(spacing: DS.Spacing.s4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                Text("Achieved")
                    .style(.micro)
            }
            .foregroundStyle(DS.Colors.Ink.tertiary)
        } else if milestone.isCurrentTarget {
            Text("\(milestone.daysToGo) To Go")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        } else {
            Text("Locked")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.disabled)
        }
    }
}

#Preview {
    NavigationStack {
        StreakDetailView()
    }
    .preferredColorScheme(.dark)
    .environment(SubscriptionService.shared)
    .modelContainer(for: [
        Discipline.self, Category.self, MasteryLevel.self,
        Drill.self, DrillProgress.self, PlayerState.self
    ])
}
