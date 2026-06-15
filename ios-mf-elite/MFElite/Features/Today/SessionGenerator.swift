import Foundation

/// What the player wants to work on. `surprise` randomizes focus + level.
enum TrainingFocus: String, CaseIterable, Identifiable {
    case balanced, ballMastery, finishing, speedAgility, dribbling, mental, surprise
    var id: String { rawValue }

    var label: String {
        switch self {
        case .balanced: return "Balanced"
        case .ballMastery: return "Ball Mastery"
        case .finishing: return "Finishing"
        case .speedAgility: return "Speed & Agility"
        case .dribbling: return "Dribbling"
        case .mental: return "Mental"
        case .surprise: return "Surprise me"
        }
    }

    /// Category-name fragments this focus pulls from. Empty == all categories.
    var categoryMatches: [String] {
        switch self {
        case .balanced, .surprise: return []
        case .ballMastery: return ["Ball Mastery"]
        case .finishing: return ["Finishing"]
        case .speedAgility: return ["Speed", "Agility"]
        case .dribbling: return ["Dribbling"]
        case .mental: return ["Self-Talk", "Focus", "Confidence", "Composure", "Match Mentality"]
        }
    }
}

/// Difficulty band, mapped onto MasteryLevel.number (1...5).
enum TrainingLevelBand: String, CaseIterable, Identifiable {
    case auto, beginner, intermediate, advanced
    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var levels: ClosedRange<Int> {
        switch self {
        case .auto: return 1...5
        case .beginner: return 1...2
        case .intermediate: return 2...4
        case .advanced: return 4...5
        }
    }
}

enum SessionGenerator {
    /// Build a time-boxed session filtered by focus and level. Never returns empty.
    static func generate(
        disciplines: [Discipline],
        focus: TrainingFocus,
        level: TrainingLevelBand,
        budgetSeconds: Int
    ) -> [DrillContext] {
        let f: TrainingFocus = (focus == .surprise)
            ? (TrainingFocus.allCases.filter { $0 != .surprise && $0 != .balanced }.randomElement() ?? .balanced)
            : focus
        let band: TrainingLevelBand = (focus == .surprise)
            ? (TrainingLevelBand.allCases.filter { $0 != .auto }.randomElement() ?? .beginner)
            : level

        var pool: [DrillContext] = []
        for d in disciplines {
            for c in d.categories {
                if !f.categoryMatches.isEmpty,
                   !f.categoryMatches.contains(where: { c.name.localizedCaseInsensitiveContains($0) }) {
                    continue
                }
                for l in c.levels where band.levels.contains(l.number) {
                    for drill in l.drills where !drill.isCoachHidden {
                        pool.append(DrillContext(drill: drill, level: l, category: c, discipline: d))
                    }
                }
            }
        }
        pool.shuffle()

        var chosen: [DrillContext] = []
        var total = 0
        for ctx in pool {
            let cost = ctx.drill.durationSec + max(0, ctx.drill.sets - 1) * 15
            if chosen.isEmpty || total + cost <= budgetSeconds {
                chosen.append(ctx)
                total += cost
            }
            if total >= budgetSeconds { break }
        }
        if chosen.isEmpty, let any = firstAnyDrill(disciplines) { chosen = [any] }
        return chosen
    }

    private static func firstAnyDrill(_ disciplines: [Discipline]) -> DrillContext? {
        for d in disciplines { for c in d.categories { for l in c.levels {
            if let dr = l.drills.first {
                return DrillContext(drill: dr, level: l, category: c, discipline: d)
            }
        } } }
        return nil
    }
}
