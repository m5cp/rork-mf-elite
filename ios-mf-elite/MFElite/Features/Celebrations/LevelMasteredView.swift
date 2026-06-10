//
//  LevelMasteredView.swift
//  MFElite
//
//  Celebration shown when every drill in a mastery level is mastered.
//

import SwiftUI
import SwiftData

struct LevelMasteredView: View {
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline

    /// Called when the player taps either CTA. The parent decides what comes next.
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var progress: [DrillProgress]

    @State private var revealNumeral = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var masteredIDs: Set<String> {
        Set(progress.filter(\.isMastered).map(\.drillID))
    }

    private var sortedLevels: [MasteryLevel] {
        category.levels.sorted { $0.number < $1.number }
    }

    private func isLevelMastered(_ level: MasteryLevel) -> Bool {
        !level.drills.isEmpty && level.drills.allSatisfy { masteredIDs.contains($0.id) }
    }

    private var masteredLevelCount: Int {
        sortedLevels.filter(isLevelMastered).count
    }

    private var totalLevels: Int { sortedLevels.count }

    private var categoryCertified: Bool {
        totalLevels > 0 && masteredLevelCount == totalLevels
    }

    private var nextLevel: MasteryLevel? {
        sortedLevels.first { $0.number > level.number }
    }

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("\(level.number)")
                    .font(.system(size: 188, weight: .heavy))
                    .italic()
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .scaleEffect(revealNumeral ? 1 : 0.3)
                    .opacity(revealNumeral ? 1 : 0)

                VStack(spacing: DS.Spacing.s8) {
                    Eyebrow(text: "Level \(level.number) · Mastered")
                    Text(level.name)
                        .style(.title1)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.s24)

                certCard
                    .padding(.top, DS.Spacing.s32)
                    .frame(maxWidth: 320)

                HStack(spacing: DS.Spacing.s8) {
                    rewardPill(text: "+\(ProgressionRules.xpLevelBonus) XP", icon: nil)
                    if let nextLevel {
                        rewardPill(text: "Level \(nextLevel.number) unlocked", icon: "lock.open")
                    } else {
                        rewardPill(text: "All levels complete", icon: "checkmark")
                    }
                }
                .padding(.top, DS.Spacing.s20)

                Spacer()

                VStack(spacing: DS.Spacing.s8) {
                    PrimaryButton(
                        label: categoryCertified ? "View certification" : "Start Level \(nextLevel?.number ?? level.number)",
                        hint: categoryCertified ? nil : "NEXT"
                    ) {
                        onClose()
                        dismiss()
                    }
                    GhostButton(label: "Back to pathway") {
                        onClose()
                        dismiss()
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s40)
            }
            .padding(.horizontal, DS.Spacing.s20)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if reduceMotion {
                revealNumeral = true
            } else {
                withAnimation(DS.Motion.celebrationSpring.delay(0.2)) {
                    revealNumeral = true
                }
            }
        }
    }

    private var certCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                HStack {
                    Eyebrow(text: "Skill Certification")
                    Spacer()
                    if categoryCertified {
                        HStack(spacing: DS.Spacing.s4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("Certified")
                                .style(.micro)
                        }
                        .foregroundStyle(DS.Colors.Ink.primary)
                    }
                }

                Text(category.certName)
                    .style(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.Ink.primary)

                Text("\(masteredLevelCount)/\(totalLevels) levels")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)

                LevelPips(
                    total: totalLevels,
                    done: masteredLevelCount - 1,
                    current: masteredLevelCount
                )
            }
        }
    }

    private func rewardPill(text: String, icon: String?) -> some View {
        HStack(spacing: DS.Spacing.s4 + 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
            }
            Text(text)
                .style(.foot)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .padding(.vertical, DS.Spacing.s8)
        .padding(.horizontal, DS.Spacing.s16)
        .background(DS.Colors.Bg.raised)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }
}
