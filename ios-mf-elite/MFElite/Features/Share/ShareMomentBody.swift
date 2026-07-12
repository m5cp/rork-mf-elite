//
//  ShareMomentBody.swift
//  MFElite
//
//  The per-moment card bodies. Each returns a set of sibling views that the
//  card's auto-fit VStack stacks and spaces. All sizes are design px at 1080-wide.
//

import SwiftUI

// MARK: - Body router

struct ShareMomentBody: View {
    let moment: ShareMoment
    let theme: ShareTheme
    let show: ShareShow

    var body: some View {
        switch moment.data {
        case let .badge(image, big, unit, title, date):
            BadgeBody(image: image, big: big, unit: unit, title: title, date: date,
                      playerLine: moment.playerLine, theme: theme, show: show)
        case let .streak(count, unit, title, badge, date):
            StreakBody(count: count, unit: unit, title: title, badge: badge, date: date,
                       playerLine: moment.playerLine, theme: theme, show: show)
        case let .playerCard(rating, position, name, club, stats):
            PlayerCardBody(rating: rating, position: position, name: name, club: club,
                           stats: stats, theme: theme, show: show)
        case let .combineResult(test, value, unit, delta, pct, pctLabel):
            CombineResultBody(test: test, value: value, unit: unit, delta: delta, pct: pct,
                              pctLabel: pctLabel, playerLine: moment.playerLine, theme: theme, show: show)
        case let .combineScorecard(overall, rows):
            CombineScorecardBody(overall: overall, rows: rows,
                                 playerLine: moment.playerLine, theme: theme, show: show)
        case let .levelMastered(badge, level, of, drill, category, sessions):
            LevelMasteredBody(badge: badge, level: level, of: of, drill: drill, category: category,
                              sessions: sessions, playerLine: moment.playerLine, theme: theme, show: show)
        case let .weeklyRecap(xp, grid):
            WeeklyRecapBody(xp: xp, grid: grid, playerLine: moment.playerLine, theme: theme, show: show)
        case let .invite(line1, line2, code, copy):
            InviteBody(line1: line1, line2: line2, code: code, copy: copy, theme: theme, show: show)
        case let .repBadge(headlineIndex):
            RepBadgeBody(headlineIndex: headlineIndex, playerLine: moment.playerLine, theme: theme, show: show)
        }
    }
}

// MARK: - Shared pieces

/// Rotated accent chip used above / around moment bodies.
struct ShareEyebrow: View {
    let text: String
    let theme: ShareTheme

    var body: some View {
        Text(text.uppercased())
            .font(ShareFont.display(40))
            .tracking(6)
            .foregroundStyle(theme.chipInk)
            .padding(.horizontal, 30)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(theme.accent)
            .rotationEffect(.degrees(-2))
    }
}

/// "LEO · #10 · U14" — first name only, shown when `show.name` is on.
private struct SharePlayerLine: View {
    let text: String
    let theme: ShareTheme

    var body: some View {
        Text(text)
            .font(ShareFont.text(38, weight: .bold))
            .tracking(4)
            .foregroundStyle(theme.sub)
            .multilineTextAlignment(.center)
    }
}

private struct ShareDateLine: View {
    let text: String
    let theme: ShareTheme

    var body: some View {
        Text(text)
            .font(ShareFont.text(30, weight: .semibold))
            .tracking(5)
            .foregroundStyle(theme.sub)
    }
}

// MARK: - 1. Badge Unlocked

private struct BadgeBody: View {
    let image: String
    let big: String
    let unit: String
    let title: String
    let date: String
    let playerLine: String
    let theme: ShareTheme
    let show: ShareShow

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .frame(width: 560, height: 560)
            .shadow(color: theme.accent.opacity(0.27), radius: 45, y: 20)

        (Text(big).foregroundStyle(theme.ink) + Text(" \(unit)").foregroundStyle(theme.accent))
            .font(ShareFont.display(150))
            .multilineTextAlignment(.center)

        ShareEyebrow(text: title, theme: theme)

        if show.name { SharePlayerLine(text: playerLine, theme: theme) }
        if show.date { ShareDateLine(text: date, theme: theme) }
    }
}

// MARK: - 2. Streak Milestone

private struct StreakBody: View {
    let count: Int
    let unit: String
    let title: String
    let badge: String
    let date: String
    let playerLine: String
    let theme: ShareTheme
    let show: ShareShow

    var body: some View {
        Text("\(count)")
            .font(ShareFont.display(520))
            .foregroundStyle(theme.accent)
            .shadow(color: theme.accent.opacity(0.33), radius: 60, y: 15)

        Text(unit.uppercased())
            .font(ShareFont.display(110))
            .tracking(10)
            .foregroundStyle(theme.ink)

        ShareEyebrow(text: title, theme: theme)

        Image(badge)
            .resizable()
            .scaledToFit()
            .frame(width: 260, height: 260)

        if show.name { SharePlayerLine(text: playerLine, theme: theme) }
        if show.date { ShareDateLine(text: date, theme: theme) }
    }
}

// MARK: - 3. Player Card

private struct PlayerCardBody: View {
    let rating: Int
    let position: String
    let name: String
    let club: String
    let stats: [ShareStat]
    let theme: ShareTheme
    let show: ShareShow

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 26), count: 3)

    var body: some View {
        HStack(alignment: .center, spacing: 60) {
            Text("\(rating)")
                .font(ShareFont.display(300))
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 0) {
                Text(position.uppercased())
                    .font(ShareFont.display(96))
                    .foregroundStyle(theme.ink)
                if show.name {
                    Text(name.uppercased())
                        .font(ShareFont.display(96))
                        .foregroundStyle(theme.ink)
                }
                Text(club.uppercased())
                    .font(ShareFont.text(32, weight: .bold))
                    .tracking(5)
                    .foregroundStyle(theme.sub)
                    .padding(.top, 14)
            }
        }

        if show.stats {
            LazyVGrid(columns: columns, spacing: 26) {
                ForEach(stats, id: \.key) { stat in
                    VStack(spacing: 8) {
                        Text("\(stat.value)")
                            .font(ShareFont.display(84))
                            .foregroundStyle(theme.ink)
                        Text(stat.key)
                            .font(ShareFont.text(26, weight: .bold))
                            .tracking(4)
                            .foregroundStyle(theme.sub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 26)
                    .padding(.bottom, 20)
                    .background(theme.neutralFill(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(theme.neutralFill(0.10), lineWidth: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .frame(width: 860)
        }

        ShareEyebrow(text: "MF ELITE PLAYER CARD", theme: theme)
    }
}

// MARK: - 4. Combine Result

private struct CombineResultBody: View {
    let test: String
    let value: String
    let unit: String
    let delta: String
    let pct: Int
    let pctLabel: String
    let playerLine: String
    let theme: ShareTheme
    let show: ShareShow

    var body: some View {
        ShareEyebrow(text: "NEW PERSONAL BEST", theme: theme)

        Text(test.uppercased())
            .font(ShareFont.display(84))
            .tracking(6)
            .foregroundStyle(theme.ink)
            .multilineTextAlignment(.center)

        (Text(value).foregroundStyle(theme.accent) + Text(" \(unit)").font(ShareFont.display(130)).foregroundStyle(theme.ink))
            .font(ShareFont.display(400))

        if show.stats {
            Text(delta)
                .font(ShareFont.text(40, weight: .bold))
                .foregroundStyle(theme.ink)

            if !pctLabel.isEmpty {
                VStack(spacing: 14) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.neutralFill(0.12))
                        Capsule().fill(theme.accent)
                            .frame(width: 760 * CGFloat(min(100, max(0, pct))) / 100)
                    }
                    .frame(width: 760, height: 22)

                    Text(pctLabel.uppercased())
                        .font(ShareFont.text(28, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(theme.sub)
                }
            }
        }

        if show.name { SharePlayerLine(text: playerLine, theme: theme) }
    }
}

// MARK: - 5. Combine Scorecard

private struct CombineScorecardBody: View {
    let overall: Int
    let rows: [ShareScoreRow]
    let playerLine: String
    let theme: ShareTheme
    let show: ShareShow

    var body: some View {
        ShareEyebrow(text: "COMBINE SCORECARD", theme: theme)

        HStack(alignment: .lastTextBaseline, spacing: 30) {
            Text("\(overall)")
                .font(ShareFont.display(260))
                .foregroundStyle(theme.accent)
            Text("OVR")
                .font(ShareFont.display(60))
                .foregroundStyle(theme.ink)
        }

        if show.stats {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.name) { index, row in
                    HStack(spacing: 28) {
                        Text(row.name.uppercased())
                            .font(ShareFont.text(34, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.neutralFill(0.12))
                            Capsule().fill(theme.accent)
                                .frame(width: 220 * CGFloat(min(100, max(0, row.pct))) / 100)
                        }
                        .frame(width: 220, height: 14)

                        Text(row.value)
                            .font(ShareFont.display(50))
                            .foregroundStyle(theme.ink)
                            .frame(width: 170, alignment: .trailing)
                    }
                    .padding(.vertical, 24)
                    .overlay(alignment: .top) {
                        if index != 0 {
                            Rectangle().fill(theme.neutralFill(0.12)).frame(height: 2)
                        }
                    }
                }
            }
            .frame(width: 880)
        }

        if show.name { SharePlayerLine(text: playerLine, theme: theme) }
    }
}

// MARK: - 6. Level Mastered

private struct LevelMasteredBody: View {
    let badge: String
    let level: Int
    let of: Int
    let drill: String
    let category: String
    let sessions: Int
    let playerLine: String
    let theme: ShareTheme
    let show: ShareShow

    var body: some View {
        Image(badge)
            .resizable()
            .scaledToFit()
            .frame(width: 420, height: 420)
            .shadow(color: theme.accent.opacity(0.27), radius: 40, y: 15)

        ShareEyebrow(text: "LEVEL \(level) MASTERED", theme: theme)

        Text(drill.uppercased())
            .font(ShareFont.display(108))
            .foregroundStyle(theme.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 900)

        HStack(spacing: 18) {
            ForEach(0..<max(of, 1), id: \.self) { index in
                RoundedRectangle(cornerRadius: 8)
                    .fill(index < level ? theme.accent : theme.neutralFill(0.16))
                    .frame(width: 44, height: 16)
            }
        }

        if show.stats {
            Text("\(category.uppercased()) · \(sessions) SESSIONS TO MASTER")
                .font(ShareFont.text(34, weight: .bold))
                .tracking(4)
                .foregroundStyle(theme.sub)
        }

        if show.name { SharePlayerLine(text: playerLine, theme: theme) }
    }
}

// MARK: - 7. Weekly Recap

private struct WeeklyRecapBody: View {
    let xp: Int
    let grid: [ShareStat]
    let playerLine: String
    let theme: ShareTheme
    let show: ShareShow

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 24), count: 2)

    var body: some View {
        ShareEyebrow(text: "THIS WEEK", theme: theme)

        Text("+\(xp)")
            .font(ShareFont.display(280))
            .foregroundStyle(theme.accent)

        Text("XP EARNED")
            .font(ShareFont.display(86))
            .tracking(8)
            .foregroundStyle(theme.ink)

        if show.stats {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(grid, id: \.key) { stat in
                    VStack(spacing: 8) {
                        Text("\(stat.value)")
                            .font(ShareFont.display(92))
                            .foregroundStyle(theme.ink)
                        Text(stat.key)
                            .font(ShareFont.text(28, weight: .bold))
                            .tracking(4)
                            .foregroundStyle(theme.sub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                    .padding(.bottom, 24)
                    .background(theme.neutralFill(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .frame(width: 800)
        }

        if show.name { SharePlayerLine(text: playerLine, theme: theme) }
    }
}

// MARK: - 8. Invite a Friend

private struct InviteBody: View {
    let line1: String
    let line2: String
    let code: String
    let copy: String
    let theme: ShareTheme
    let show: ShareShow

    private var logoAsset: String {
        theme.isLight ? "mf-logo-black" : "mf-logo-white"
    }

    var body: some View {
        Image(logoAsset)
            .resizable()
            .scaledToFit()
            .frame(width: 380)

        VStack(spacing: 0) {
            Text(line1.uppercased())
                .foregroundStyle(theme.ink)
            Text(line2.uppercased())
                .foregroundStyle(theme.accent)
        }
        .font(ShareFont.display(160))
        .multilineTextAlignment(.center)

        if show.name {
            Text("FRIEND CODE \(code)")
                .font(ShareFont.text(40, weight: .bold))
                .tracking(6)
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 44)
                .padding(.vertical, 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(style: StrokeStyle(lineWidth: 3, dash: [14, 10]))
                        .foregroundStyle(theme.accent)
                )
        }

        Text(copy)
            .font(ShareFont.text(34, weight: .medium))
            .foregroundStyle(theme.sub)
            .multilineTextAlignment(.center)
            .lineSpacing(8)
            .frame(maxWidth: 760)
    }
}

// MARK: - 9. Rep The Badge

private struct RepBadgeBody: View {
    let headlineIndex: Int
    let playerLine: String
    let theme: ShareTheme
    let show: ShareShow

    private var logoAsset: String {
        theme.isLight ? "mf-logo-black" : "mf-logo-white"
    }

    /// Split the headline so the last word renders in the accent color.
    private var headlineParts: (lead: String, last: String) {
        let headline = ShareMoment.repHeadlines[
            min(max(0, headlineIndex), ShareMoment.repHeadlines.count - 1)
        ]
        var words = headline.split(separator: " ").map(String.init)
        guard let last = words.popLast() else { return (headline, "") }
        return (words.joined(separator: " "), last)
    }

    var body: some View {
        Image(logoAsset)
            .resizable()
            .scaledToFit()
            .frame(width: 460)

        let parts = headlineParts
        Group {
            if parts.lead.isEmpty {
                Text(parts.last).foregroundStyle(theme.accent)
            } else {
                Text("\(parts.lead) ").foregroundStyle(theme.ink)
                    + Text(parts.last).foregroundStyle(theme.accent)
            }
        }
        .font(ShareFont.display(150))
        .multilineTextAlignment(.center)

        if show.name { SharePlayerLine(text: playerLine, theme: theme) }
    }
}
