//
//  WeeklyRecapView.swift
//  MFElite
//
//  This week's training story, distilled into a shareable recap: days trained,
//  XP earned, minutes on the ball, the current streak, and any rank climbed.
//  Computed entirely from local SessionLogEntry history, so it works offline.
//  Surfaced compactly on Today and in a fuller, shareable form in Progress.
//

import SwiftUI
import SwiftData

// MARK: - Recap model (pure)

/// A read-only summary of the player's current Monday→Sunday week.
nonisolated struct WeekRecap {
    /// Distinct calendar days trained this week.
    let sessions: Int
    /// Drills completed this week.
    let drills: Int
    /// XP earned this week.
    let xp: Int
    /// Minutes trained this week (real training time, excludes rest).
    let minutes: Int
    /// The player's current streak.
    let streak: Int
    /// The rank title the player climbed into this week, if their rank went up.
    let rankClimbedTo: String?

    var hasActivity: Bool { drills > 0 }

    init(sessions logs: [SessionLogEntry], currentXP: Int, currentStreak: Int) {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysSinceMonday = (weekday - cal.firstWeekday + 7) % 7
        let monday = cal.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let nextMonday = cal.date(byAdding: .day, value: 7, to: monday) ?? today

        let thisWeek = logs.filter { $0.completedAt >= monday && $0.completedAt < nextMonday }

        self.drills = thisWeek.count
        self.xp = thisWeek.reduce(0) { $0 + $1.xpEarned }
        self.minutes = max(thisWeek.isEmpty ? 0 : 1, Int((Double(thisWeek.reduce(0) { $0 + $1.durationSec }) / 60).rounded()))
        self.streak = currentStreak

        let trainedDays = Set(thisWeek.map { cal.startOfDay(for: $0.completedAt) })
        self.sessions = trainedDays.count

        // Rank movement: compare the rank held before this week's XP to now.
        let startXP = max(0, currentXP - self.xp)
        let before = AcademyRank.rank(for: startXP)
        let now = AcademyRank.rank(for: currentXP)
        self.rankClimbedTo = now.rawValue > before.rawValue ? now.title : nil
    }
}

// MARK: - Compact card (Today)

/// A tappable, glanceable recap shown on the Today screen during the week.
struct WeeklyRecapCompactCard: View {
    let recap: WeekRecap
    var onShare: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                HStack {
                    Eyebrow(text: "This Week")
                    Spacer()
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Share weekly recap")
                }

                HStack(spacing: 0) {
                    stat("\(recap.sessions)", recap.sessions == 1 ? "Day" : "Days")
                    divider
                    stat("+\(recap.xp)", "XP")
                    divider
                    stat("\(recap.minutes)", "Min")
                    divider
                    stat("\(recap.streak)", "Streak")
                }

                if let rank = recap.rankClimbedTo {
                    HStack(spacing: DS.Spacing.s8) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "#3DD68C"))
                        Text("Climbed to \(rank) this week")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                    }
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 24))
                .tracking(-0.6)
                .foregroundStyle(DS.Colors.Ink.primary)
            Eyebrow(text: label)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 36)
    }
}

// MARK: - Full section (Progress)

/// The fuller weekly recap shown in the Progress tab, with a Share action.
struct WeeklyRecapSection: View {
    let recap: WeekRecap
    let playerName: String

    @State private var sharePreview: ShareMoment?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Your Week")
                .padding(.bottom, DS.Spacing.s4)

            Card(raised: true) {
                VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                    HStack(spacing: 0) {
                        stat("\(recap.sessions)", recap.sessions == 1 ? "Day Trained" : "Days Trained")
                        divider
                        stat("+\(recap.xp)", "XP Gained")
                        divider
                        stat("\(recap.minutes)", "Minutes")
                    }

                    Hairline()

                    HStack(spacing: DS.Spacing.s12) {
                        Image(systemName: recap.rankClimbedTo != nil ? "arrow.up.right.circle.fill" : "flame.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text(narrative)
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button {
                shareThisWeek()
            } label: {
                Label("Share this", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, DS.Spacing.s8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32 - 4)
        .fullScreenCover(item: $sharePreview) { moment in
            ShareEditorView(moment: moment)
        }
    }

    private var narrative: String {
        if let rank = recap.rankClimbedTo {
            return "Climbed to \(rank) this week — \(recap.streak)-day streak and counting."
        }
        if recap.streak >= 2 {
            return "\(recap.streak)-day streak going strong. Keep it rolling."
        }
        return "\(recap.drills) drill\(recap.drills == 1 ? "" : "s") banked this week. Momentum starts now."
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: DS.Spacing.s4) {
            Text(value)
                .font(DS.Typography.num(size: 30))
                .tracking(-1)
                .foregroundStyle(DS.Colors.Ink.primary)
            Eyebrow(text: label)
                .multilineTextAlignment(.center)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(DS.Colors.Line.hairline)
            .frame(width: 1, height: 44)
    }

    /// Deep-links into the share flow with this week's recap preselected as a
    /// branded Weekly Recap card.
    private func shareThisWeek() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sharePreview = ShareMomentBuilder.weeklyRecap(recap)
    }
}

// MARK: - Shareable card

/// The branded image exported when sharing the weekly recap.
struct WeeklyRecapShareCard: View {
    let recap: WeekRecap
    let playerName: String

    var body: some View {
        MFShareCard(eyebrow: "This Week") {
            VStack(spacing: DS.Spacing.s16) {
                Text(ShareText.firstName(playerName))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 0) {
                    stat("\(recap.sessions)", recap.sessions == 1 ? "Day" : "Days")
                    stat("+\(recap.xp)", "XP")
                    stat("\(recap.minutes)", "Min")
                    stat("\(recap.streak)", "Streak")
                }

                Text(recap.rankClimbedTo.map { "Climbed to \($0)." } ?? "On the grind.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, DS.Spacing.s8)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
