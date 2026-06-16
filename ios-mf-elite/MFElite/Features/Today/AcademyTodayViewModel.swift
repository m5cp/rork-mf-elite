//
//  AcademyTodayViewModel.swift
//  MFElite
//
//  Derives the daily dashboard presentation from the curriculum and player state.
//

import Foundation
import Observation

/// A single daily goal and whether it has been satisfied today.
struct GoalState: Identifiable {
    let id: Int
    let label: String
    let done: Bool
    var drillRoute: DrillRoute? = nil
    var levelRoute: LevelRoute? = nil
}

/// The player's current in-progress level plus its parent context.
struct CurrentFocus {
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline
}

/// One recommended drill for a discipline, carrying full navigation context.
struct Recommendation: Identifiable {
    let drill: Drill
    let category: Category
    let level: MasteryLevel
    let discipline: Discipline
    let reason: String

    var id: String { drill.id }
}

/// The day's single most important focus, with a coached explanation of why
/// it was chosen, derived adaptively from position, weak areas and felt ratings.
struct PlanFocus: Identifiable {
    let drill: Drill
    let category: Category
    let level: MasteryLevel
    let discipline: Discipline
    /// Short tag, e.g. "Weak Foot" or "Finishing".
    let headline: String
    /// One human sentence explaining why this is today's focus.
    let reason: String
    /// A short, encouraging momentum line (streak / bounce-back / stepping up).
    let momentum: String?

    var id: String { drill.id }
}

/// How tough the player's recent sessions have felt, used to nudge difficulty.
enum DifficultyTrend {
    /// Recent work felt easy and is getting mastered — step toward a challenge.
    case stepUp
    /// Recent work felt brutal — ease back so the player doesn't burn out.
    case easeBack
    /// No strong signal — follow the normal pathway order.
    case steady
}

@MainActor
@Observable
final class AcademyTodayViewModel {
    let disciplines: [Discipline]
    let xp: Int
    let streak: Int

    private let masteredDrillIDs: Set<String>
    private let passesByDrill: [String: Int]
    private let drillsLoggedToday: Set<String>
    /// drillID → owning discipline name, for resolving today's activity.
    private let disciplineNameByDrill: [String: String]
    /// drillID → owning category name.
    private let categoryNameByDrill: [String: String]
    /// drillID → most recent felt rating (1 tough … 5 easy), from the training log.
    private let latestRatingByDrill: [String: Int]
    /// disciplineID → number of sessions logged in the last 14 days.
    private let recentSessionsByDiscipline: [String: Int]
    /// The player's position code (e.g. "ST", "CB"), used to bias the focus.
    private let positionCode: String
    /// Lowest mastery-level number the plan biases toward for players with no
    /// progress yet. 1 = no bias. Lower content is never locked.
    private let startingLevelBias: Int
    /// Game IQ lessons, used to alternate the Tactical recommendation with lessons.
    private let gameIQLessons: [GameIQLesson]
    /// Most recent Tactical drill completion (excludes Game IQ lesson log entries).
    private let lastTacticalDrillDate: Date?
    /// Rated Technical drill completions, for the Match Day pre-game cue line.
    let recentTechnicalRatings: [(drillID: String, rating: Int, date: Date)]
    /// All rated sessions over the trailing 10 days, newest first, used to read
    /// how tough recent work has felt and to drive momentum + difficulty.
    private let recentRatedSessions: [(rating: Int, date: Date)]
    /// Drills mastered in the last 7 days, a signal the player is progressing fast.
    private let masteriesThisWeek: Int

    init(
        disciplines: [Discipline],
        xp: Int,
        streak: Int,
        progress: [DrillProgress],
        sessions: [SessionLogEntry] = [],
        positionCode: String = "",
        startingLevelBias: Int = 1,
        gameIQLessons: [GameIQLesson] = []
    ) {
        self.startingLevelBias = max(1, startingLevelBias)
        let sorted = disciplines.sorted { $0.sortIndex < $1.sortIndex }
        self.disciplines = sorted
        self.xp = xp
        self.streak = streak

        self.masteredDrillIDs = Set(progress.filter { $0.isMastered }.map { $0.drillID })
        self.passesByDrill = Dictionary(
            progress.map { ($0.drillID, $0.passesLogged) },
            uniquingKeysWith: { a, _ in a }
        )

        let calendar = Calendar.current
        self.drillsLoggedToday = Set(
            progress
                .filter { entry in
                    guard let date = entry.lastLoggedAt else { return false }
                    return calendar.isDateInToday(date)
                }
                .map { $0.drillID }
        )

        var disciplineMap: [String: String] = [:]
        var categoryMap: [String: String] = [:]
        for discipline in sorted {
            for category in discipline.categories {
                for level in category.levels {
                    for drill in level.drills {
                        disciplineMap[drill.id] = discipline.name
                        categoryMap[drill.id] = category.name
                    }
                }
            }
        }
        self.disciplineNameByDrill = disciplineMap
        self.categoryNameByDrill = categoryMap
        self.positionCode = positionCode.uppercased()

        // Most recent felt rating per drill (newest log wins).
        var ratingMap: [String: Int] = [:]
        for entry in sessions.sorted(by: { $0.completedAt > $1.completedAt }) {
            guard let rating = entry.feltRating else { continue }
            if ratingMap[entry.drillID] == nil { ratingMap[entry.drillID] = rating }
        }
        self.latestRatingByDrill = ratingMap

        // Sessions per discipline over the trailing 14 days, to spot neglected areas.
        let cutoff = calendar.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
        var recentMap: [String: Int] = [:]
        for entry in sessions where entry.completedAt >= cutoff {
            recentMap[entry.disciplineID, default: 0] += 1
        }
        self.recentSessionsByDiscipline = recentMap

        self.gameIQLessons = gameIQLessons
        self.lastTacticalDrillDate = sessions
            .filter { ($0.disciplineName == "Tactical" || $0.disciplineID == "d-tact") && $0.sourceName != "Game IQ" }
            .map(\.completedAt)
            .max()

        self.recentTechnicalRatings = sessions.compactMap { entry in
            guard entry.disciplineName == "Technical" || entry.disciplineID == "d-tech" else { return nil }
            guard let rating = entry.feltRating else { return nil }
            return (drillID: entry.drillID, rating: rating, date: entry.completedAt)
        }

        let ratedCutoff = calendar.date(byAdding: .day, value: -10, to: Date()) ?? .distantPast
        self.recentRatedSessions = sessions
            .filter { $0.completedAt >= ratedCutoff }
            .compactMap { entry in entry.feltRating.map { (rating: $0, date: entry.completedAt) } }
            .sorted { $0.date > $1.date }

        let weekCutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        self.masteriesThisWeek = progress.filter { entry in
            guard entry.isMastered, let date = entry.lastLoggedAt else { return false }
            return date >= weekCutoff
        }.count
    }

    // MARK: - Difficulty + momentum

    /// Average felt rating across the player's three most recent rated sessions
    /// (1 tough … 5 easy). `nil` when there aren't enough rated sessions yet.
    private var recentFeltAverage: Double? {
        let recent = recentRatedSessions.prefix(3).map(\.rating)
        guard recent.count >= 2 else { return nil }
        return Double(recent.reduce(0, +)) / Double(recent.count)
    }

    /// Whether to nudge the focus toward a harder or easier drill based on how
    /// recent sessions have felt. Steady when there isn't a clear signal.
    var difficultyTrend: DifficultyTrend {
        guard let average = recentFeltAverage else { return .steady }
        if average >= 4.0 { return .stepUp }
        if average <= 2.0 { return .easeBack }
        return .steady
    }

    /// A short, encouraging momentum line shown under the focus reason. Reads the
    /// streak, how tough recent work felt, and weekly mastery pace.
    var momentumLine: String? {
        switch difficultyTrend {
        case .easeBack:
            return "Recent sessions felt tough — today we ease back and rebuild the touch."
        case .stepUp:
            if streak >= 3 {
                return "\(streak)-day streak and the work's feeling easy — time to level up."
            }
            return "You're making it look easy. Let's raise the bar today."
        case .steady:
            break
        }
        if streak >= 7 {
            return "\(streak) days straight. This is what separation looks like."
        }
        if streak >= 3 {
            return "\(streak)-day streak going — keep the fire lit."
        }
        if masteriesThisWeek >= 3 {
            return "\(masteriesThisWeek) drills mastered this week. Momentum is yours."
        }
        if streak == 0 {
            return "One session restarts the streak. Let's get the first touch in."
        }
        return nil
    }

    // MARK: - Game IQ alternation

    /// True for the Tactical discipline, used to swap its recommendation for a lesson.
    func isTactical(_ discipline: Discipline) -> Bool {
        discipline.name == "Tactical" || discipline.id == "d-tact"
    }

    /// The next uncompleted Game IQ lesson to surface in place of the Tactical
    /// drill recommendation, or nil when none remain or it's a drill's turn.
    /// Alternation rule: a lesson is offered only when the most recent Tactical
    /// completion was a drill (so completions cycle drill → lesson → drill …).
    var tacticalLessonSuggestion: GameIQLesson? {
        guard let next = gameIQLessons
            .filter({ !$0.isCompleted })
            .sorted(by: { $0.sortIndex < $1.sortIndex })
            .first else { return nil }
        let lastLessonDate = gameIQLessons.compactMap(\.completedAt).max()
        let mostRecentWasDrill: Bool = {
            guard let drillDate = lastTacticalDrillDate else { return false }
            guard let lessonDate = lastLessonDate else { return true }
            return drillDate > lessonDate
        }()
        return mostRecentWasDrill ? next : nil
    }

    // MARK: - Salutation

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case ..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default:     return "Good evening,"
        }
    }

    var playerName: String { PlayerProfileStore.shared.displayName }
    var playerInitials: String { PlayerProfileStore.shared.initials }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        let day = formatter.string(from: Date()).uppercased()
        return "\(day) · Season 25—26"
    }

    // MARK: - Daily quote

    private static let quotes: [String] = [
        "Full effort is the only standard.",
        "The ball doesn't care about yesterday.",
        "Train like you've never won. Play like you've never lost.",
        "Discipline is choosing what you want most over what you want now.",
        "Every touch is a chance to improve.",
        "Champions are built in the sessions nobody sees.",
        "Your feet are your tools. Sharpen them daily.",
        "Pressure is a privilege.",
        "The difference between good and great is one more rep.",
        "Control the ball. Control the game.",
        "Do it when you don't feel like it. That's the edge.",
        "Touch the ball every single day. No exceptions.",
        "You are what you repeat.",
        "Small sessions, done daily, beat long sessions done occasionally.",
        "The best players in the world were once where you are now.",
        "Your weak foot is not optional. It is a weapon waiting to be built.",
        "Speed without control is just chaos.",
        "Every rep matters. Even the ones nobody sees.",
        "Train like you play. Play like you train.",
        "Focus is a skill. Practice it.",
        "The player who works hardest in the off-season wins in the season.",
        "Master the basics. Then master them again.",
        "Composure under pressure is trained, not given.",
        "Your body follows your mind. Think sharp, move sharp.",
        "Nobody remembers the excuses. They remember the results.",
        "There is no substitute for ball time.",
        "Be the player that coaches trust in the big moments.",
        "You control two things: your effort and your attitude.",
        "Your first touch determines everything that follows.",
        "Champions are built in the dark. Keep training.",
        "Talent is common. Discipline is rare.",
        "You don't rise to the occasion. You fall to the level of your training.",
        "Play with purpose. Every touch has intention.",
        "Rest is part of the process. Recover well.",
        "Mental strength is the most underrated skill in soccer.",
        "Be coachable. The best players always are.",
        "Consistency beats intensity. Show up every day.",
        "Play the game in your head before you play it on the pitch.",
        "Your position is earned. Never stop earning it.",
        "The ball moves faster than your feet. Think ahead.",
        "Make the simple pass. Make it perfectly.",
        "Watch the game. Study the game. Live the game.",
        "Your body is your tool. Respect it. Fuel it. Train it.",
        "The difference between a pass and a great pass is timing.",
        "Soccer is a thinking game played with your feet.",
        "Today's session is tomorrow's instinct.",
        "You miss 100% of the reps you skip.",
        "A strong mind controls a tired body.",
        "The pitch doesn't owe you anything. Earn every yard.",
        "Confidence comes from preparation. Prepare.",
        "Vision is seeing what others don't. Scan more.",
        "Movement off the ball is where games are won.",
        "Every champion was once a beginner who refused to quit.",
        "The players who last are the ones who love the process.",
        "Mistakes are data. Learn from every one.",
        "Be the hardest worker on the pitch. Every single time.",
        "Practice doesn't make perfect. Perfect practice makes perfect.",
        "Speed of thought beats speed of feet.",
        "Stay hungry. Stay humble. Stay sharp.",
        "The grind is the glory. Love the work."
    ]

    var dailyQuote: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return Self.quotes[(dayOfYear - 1) % Self.quotes.count]
    }

    // MARK: - Rank

    var currentRank: AcademyRank { AcademyRank.unlockedRank(for: xp, hasFullAccess: SubscriptionService.shared.hasFullAccess) }

    // MARK: - Daily goals

    var goalStates: [GoalState] {
        let ballMasteryToday = drillsLoggedToday.contains { categoryNameByDrill[$0] == "Ball Mastery" }
        let physicalToday = drillsLoggedToday.contains { disciplineNameByDrill[$0] == "Physical" }
        let mindToday = drillsLoggedToday.contains { disciplineNameByDrill[$0] == "Mental" }
        return [
            GoalState(
                id: 0, label: "Ball Mastery — 1 drill", done: ballMasteryToday,
                drillRoute: firstUnmasteredDrill { _, category in category.name == "Ball Mastery" }
            ),
            GoalState(
                id: 1, label: "Physical — 1 drill", done: physicalToday,
                drillRoute: firstUnmasteredDrill { discipline, _ in discipline.name == "Physical" }
            ),
            GoalState(
                id: 2, label: "Mind — 1 exercise", done: mindToday,
                drillRoute: firstUnmasteredDrill { discipline, _ in discipline.name == "Mental" }
            )
        ]
    }

    /// First not-yet-mastered drill matching a discipline/category predicate,
    /// for navigating directly to a goal's next actionable drill.
    private func firstUnmasteredDrill(matching: (Discipline, Category) -> Bool) -> DrillRoute? {
        for discipline in disciplines {
            for category in sortedCategories(discipline) where matching(discipline, category) {
                for level in sortedLevels(category) {
                    if let drill = sortedDrills(level).first(where: { !masteredDrillIDs.contains($0.id) }) {
                        return DrillRoute(discipline: discipline, category: category, level: level, drill: drill)
                    }
                }
            }
        }
        return nil
    }

    var dailyGoalsTotal: Int { goalStates.count }
    var dailyGoalsCompleted: Int { goalStates.filter { $0.done }.count }
    var todaysDrillCount: Int { drillsLoggedToday.count }

    var totalDrills: Int {
        disciplines.reduce(0) { partial, discipline in
            partial + discipline.categories.reduce(0) { sub, category in
                sub + category.levels.reduce(0) { $0 + $1.drills.count }
            }
        }
    }

    // MARK: - Continue your pathway

    /// First level with progress that isn't fully mastered; falls back to the
    /// first level anywhere that still has unmastered drills.
    var currentFocus: CurrentFocus? {
        if let focus = firstLevel(requireProgress: true) { return focus }
        return firstLevel(requireProgress: false)
    }

    private func firstLevel(requireProgress: Bool) -> CurrentFocus? {
        for discipline in disciplines {
            for category in sortedCategories(discipline) {
                for level in sortedLevels(category) {
                    let drills = level.drills
                    guard !drills.isEmpty else { continue }
                    let allMastered = drills.allSatisfy { masteredDrillIDs.contains($0.id) }
                    if allMastered { continue }
                    if requireProgress {
                        let anyProgress = drills.contains { (passesByDrill[$0.id] ?? 0) > 0 }
                        if !anyProgress { continue }
                    }
                    return CurrentFocus(level: level, category: category, discipline: discipline)
                }
            }
        }
        return nil
    }

    func masteredDrillCount(in level: MasteryLevel) -> Int {
        level.drills.filter { masteredDrillIDs.contains($0.id) }.count
    }

    // MARK: - Adaptive focus

    /// Categories worth leaning into for each position code. The first match that
    /// still has actionable work becomes the day's focus.
    private func preferredCategories(for code: String) -> [String] {
        switch code {
        case "ST":          return ["Finishing", "First Touch", "Movement Off the Ball"]
        case "LW", "RW":    return ["Dribbling & 1v1", "Finishing", "Speed & Acceleration"]
        case "CAM":         return ["Passing & Receiving", "Finishing", "Decision Making"]
        case "CM":          return ["Passing & Receiving", "Scanning & Awareness", "Decision Making"]
        case "LB", "RB":    return ["Speed & Acceleration", "Positioning", "Dribbling & 1v1"]
        case "CB":          return ["Strength & Stability", "Positioning", "First Touch"]
        case "GK":          return ["First Touch", "Composure", "Agility & Change of Direction"]
        default:            return ["Ball Mastery", "First Touch"]
        }
    }

    private var positionName: String {
        PitchPosition.all.first { $0.code.replacingOccurrences(of: "2", with: "") == positionCode }?.name ?? "player"
    }

    /// The single most valuable thing to train today, with a coached reason.
    var todaysFocus: PlanFocus? {
        // 1. Position-led: the highest-priority preferred category that still has work.
        for categoryName in preferredCategories(for: positionCode) {
            if let drill = nextActionableDrill(inCategoryNamed: categoryName) {
                let reason = focusReason(forCategory: categoryName, isPositionLed: true, rating: latestRatingByDrill[drill.drill.id])
                return PlanFocus(
                    drill: drill.drill, category: drill.category, level: drill.level,
                    discipline: drill.discipline, headline: categoryName, reason: reason,
                    momentum: momentumLine
                )
            }
        }
        // 2. Weakest discipline: lowest recent activity + lowest mastery that still has work.
        if let weak = weakestDiscipline(), let drill = nextActionableDrill(inDiscipline: weak) {
            let reason = focusReason(forCategory: drill.category.name, isPositionLed: false, rating: latestRatingByDrill[drill.drill.id])
            return PlanFocus(
                drill: drill.drill, category: drill.category, level: drill.level,
                discipline: drill.discipline, headline: drill.category.name, reason: reason,
                momentum: momentumLine
            )
        }
        // 3. Fallback: first actionable anywhere.
        for discipline in disciplines {
            if let drill = nextActionableDrill(inDiscipline: discipline) {
                return PlanFocus(
                    drill: drill.drill, category: drill.category, level: drill.level,
                    discipline: drill.discipline, headline: drill.category.name,
                    reason: "A clean place to start building momentum today.",
                    momentum: momentumLine
                )
            }
        }
        return nil
    }

    /// A short, human explanation shown under the focus headline. Reads the
    /// player's position, recent felt difficulty, neglect and progress pace, and
    /// varies day to day (deterministically) so it feels like a real coach.
    private func focusReason(forCategory name: String, isPositionLed: Bool, rating: Int?) -> String {
        let lower = name.lowercased()

        // Weak foot is always the highest-signal, most specific cue.
        if name.localizedCaseInsensitiveContains("weak foot") {
            return "Your weak foot needs reps — it's the fastest way to double your options on the ball."
        }

        // Difficulty-aware cues take priority — they reflect how the work felt.
        switch difficultyTrend {
        case .easeBack:
            return "Last few felt heavy, so today's \(lower) work is lighter — clean reps over grinding."
        case .stepUp:
            return "\(name) is clicking for you — today steps it up so you keep climbing."
        case .steady:
            break
        }

        if let rating, rating <= 2 {
            return "This felt tough last time, so it's back today — that's exactly where the growth is."
        }

        if isPositionLed {
            let options = [
                "As a \(positionName.lowercased()), sharpening \(lower) pays off most on match day.",
                "Top \(positionName.lowercased())s live and die by their \(lower). Today we build it.",
                "This is the \(lower) work that makes you dangerous in your \(positionName.lowercased()) role."
            ]
            return options[reasonVariant % options.count]
        }

        let options = [
            "You've trained \(lower) the least lately — time to even it out.",
            "\(name) has gone quiet in your log. Let's bring it back up to speed.",
            "Rounding out your game: \(lower) is the gap to close today."
        ]
        return options[reasonVariant % options.count]
    }

    /// A stable per-day index so the coach line varies across days without
    /// flickering as the view re-renders within a single day.
    private var reasonVariant: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
    }

    /// The discipline with the least recent activity, preferring lower mastery to break ties.
    private func weakestDiscipline() -> Discipline? {
        disciplines
            .filter { discipline in
                discipline.categories.contains { category in
                    category.levels.contains { level in
                        level.drills.contains { !masteredDrillIDs.contains($0.id) }
                    }
                }
            }
            .min { a, b in
                let ra = recentSessionsByDiscipline[a.id] ?? 0
                let rb = recentSessionsByDiscipline[b.id] ?? 0
                if ra != rb { return ra < rb }
                return masteryRatio(a) < masteryRatio(b)
            }
    }

    private func masteryRatio(_ discipline: Discipline) -> Double {
        let drills = discipline.categories.flatMap { $0.levels.flatMap(\.drills) }
        guard !drills.isEmpty else { return 1 }
        let mastered = drills.filter { masteredDrillIDs.contains($0.id) }.count
        return Double(mastered) / Double(drills.count)
    }

    /// Next not-yet-mastered drill within a discipline, preferring a level already
    /// started, then a drill recently rated tough (resurfaced sooner).
    private func nextActionableDrill(inDiscipline discipline: Discipline) -> Recommendation? {
        for category in sortedCategories(discipline) {
            if let rec = nextActionableDrill(inCategory: category, discipline: discipline) {
                return rec
            }
        }
        return nil
    }

    private func nextActionableDrill(inCategoryNamed name: String) -> Recommendation? {
        for discipline in disciplines {
            for category in sortedCategories(discipline) where category.name == name {
                if let rec = nextActionableDrill(inCategory: category, discipline: discipline) {
                    return rec
                }
            }
        }
        return nil
    }

    private func nextActionableDrill(inCategory category: Category, discipline: Discipline) -> Recommendation? {
        for level in sortedLevels(category) {
            let drills = sortedDrills(level)
            let unmastered = drills.filter { !masteredDrillIDs.contains($0.id) }
            guard !unmastered.isEmpty else { continue }
            // Prefer a drill rated tough recently; otherwise the next in sequence.
            let tough = unmastered.first { (latestRatingByDrill[$0.id] ?? 5) <= 2 }
            let pick = tough ?? unmastered[0]
            return Recommendation(
                drill: pick, category: category, level: level,
                discipline: discipline, reason: "Next in pathway"
            )
        }
        return nil
    }

    // MARK: - Recommendations

    /// Per-discipline recommendations, with the focus discipline surfaced first.
    var recommendations: [Recommendation] {
        let all = disciplines.compactMap { recommendation(for: $0) }
        guard let focusDisciplineID = todaysFocus?.discipline.id else { return all }
        return all.sorted { a, b in
            let aFocus = a.discipline.id == focusDisciplineID
            let bFocus = b.discipline.id == focusDisciplineID
            if aFocus != bFocus { return aFocus }
            return false
        }
    }

    private func recommendation(for discipline: Discipline) -> Recommendation? {
        // Prefer the next unmastered drill in a level the player has started.
        for category in sortedCategories(discipline) {
            for level in sortedLevels(category) {
                let drills = sortedDrills(level)
                let anyProgress = drills.contains { (passesByDrill[$0.id] ?? 0) > 0 }
                guard anyProgress else { continue }
                if let next = drills.first(where: { !masteredDrillIDs.contains($0.id) }) {
                    return Recommendation(
                        drill: next, category: category, level: level,
                        discipline: discipline, reason: "Next in pathway"
                    )
                }
            }
        }
        // No progress yet — surface the first drill at/above the player's
        // starting level (lower levels stay reachable, never locked).
        if let category = sortedCategories(discipline).first,
           let level = biasedLevels(category).first,
           let drill = sortedDrills(level).first {
            return Recommendation(
                drill: drill, category: category, level: level,
                discipline: discipline, reason: "Try something new"
            )
        }
        return nil
    }

    // MARK: - Quick Train

    /// Total seconds a drill takes: work across all sets + 15s rest between sets.
    static func estimatedSeconds(_ d: Drill) -> Int {
        d.durationSec * d.sets + max(0, d.sets - 1) * 15
    }

    /// Assemble a time-boxed Quick Train queue.
    ///
    /// Fill order:
    /// 1. For each INCOMPLETE daily goal (in ring order), the next unmastered
    ///    drill of that discipline (same logic the tappable goals use).
    /// 2. Then continue with next-unmastered drills across disciplines.
    /// Drills are added while the remaining budget is positive; always include at
    /// least one drill, and stop once the budget is exceeded (never by more than
    /// one drill). Mental "journal" exercises are excluded — they don't time-box.
    func quickTrainItems(budgetSeconds: Int) -> [DrillContext] {
        var picked: [DrillContext] = []
        var pickedIDs: Set<String> = []
        var remaining = budgetSeconds

        func eligible(_ drill: Drill) -> Bool {
            !masteredDrillIDs.contains(drill.id)
            && !pickedIDs.contains(drill.id)
            && drill.exerciseKind != "journal"
        }

        func add(_ ctx: DrillContext) {
            picked.append(ctx)
            pickedIDs.insert(ctx.drill.id)
            remaining -= Self.estimatedSeconds(ctx.drill)
        }

        /// True while another drill may still be appended (budget left, or nothing yet).
        var canAddMore: Bool { picked.isEmpty || remaining > 0 }

        // Phase 1 — one drill per incomplete daily goal, in ring order.
        for goal in goalStates where !goal.done {
            guard canAddMore else { break }
            if let ctx = firstUnmasteredContext(forGoal: goal.id, eligible: eligible) {
                add(ctx)
            }
        }

        // Phase 2 — continue with next-unmastered drills across all disciplines,
        // biased to start near the player's level.
        disciplineLoop: for discipline in disciplines {
            for category in sortedCategories(discipline) {
                for level in biasedLevels(category) {
                    for drill in sortedDrills(level) where eligible(drill) {
                        guard canAddMore else { break disciplineLoop }
                        add(DrillContext(drill: drill, level: level, category: category, discipline: discipline))
                    }
                }
            }
        }

        return picked
    }

    /// First eligible (unmastered, non-journal) drill matching a daily goal,
    /// mirroring the predicates used to build `goalStates`.
    private func firstUnmasteredContext(
        forGoal goalID: Int,
        eligible: (Drill) -> Bool
    ) -> DrillContext? {
        let matches: (Discipline, Category) -> Bool
        switch goalID {
        case 0:  matches = { _, category in category.name == "Ball Mastery" }
        case 1:  matches = { discipline, _ in discipline.name == "Physical" }
        case 2:  matches = { discipline, _ in discipline.name == "Mental" }
        default: return nil
        }
        for discipline in disciplines {
            for category in sortedCategories(discipline) where matches(discipline, category) {
                for level in biasedLevels(category) {
                    for drill in sortedDrills(level) where eligible(drill) {
                        return DrillContext(drill: drill, level: level, category: category, discipline: discipline)
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Match Day

    /// Work seconds for a drill: duration across all sets (no rest), used to keep
    /// the activation pairing short.
    private func matchDayWorkSec(_ ctx: DrillContext) -> Int {
        ctx.drill.durationSec * ctx.drill.sets
    }

    /// Assemble the Match Day pre-game routine from existing content:
    /// two quick physical activation drills, one visualization exercise, and one
    /// Self-Talk / Confidence exercise. Returns whatever could be resolved (the
    /// queue still runs if a section is empty).
    func matchDayItems() -> [DrillContext] {
        var result: [DrillContext] = []
        var used: Set<String> = []

        let activation = matchDayActivation()
        result.append(contentsOf: activation)
        used.formUnion(activation.map(\.drill.id))

        if let viz = nextMentalExercise(
            matching: { $0.drill.exerciseKind == "visualization" },
            excluding: used
        ) {
            result.append(viz)
            used.insert(viz.drill.id)
        }

        if let mind = nextMentalExercise(
            matching: { ["Self-Talk", "Confidence"].contains($0.category.name) },
            excluding: used
        ) {
            result.append(mind)
            used.insert(mind.drill.id)
        }

        return result
    }

    /// Two physical activation drills — preferring one each from Mobility & Recovery
    /// and Speed & Acceleration, unmastered first, keeping the pair under ~4 minutes.
    private func matchDayActivation() -> [DrillContext] {
        func candidates(in name: String) -> [DrillContext] {
            var list: [DrillContext] = []
            for discipline in disciplines {
                for category in sortedCategories(discipline) where category.name == name {
                    for level in sortedLevels(category) {
                        for drill in sortedDrills(level) where drill.exerciseKind == nil {
                            list.append(DrillContext(drill: drill, level: level, category: category, discipline: discipline))
                        }
                    }
                }
            }
            return list.sorted { a, b in
                let aMastered = masteredDrillIDs.contains(a.drill.id)
                let bMastered = masteredDrillIDs.contains(b.drill.id)
                if aMastered != bMastered { return !aMastered }
                return matchDayWorkSec(a) < matchDayWorkSec(b)
            }
        }

        let budget = 240
        let mobility = candidates(in: "Mobility & Recovery")
        let speed = candidates(in: "Speed & Acceleration")

        // Prefer one from each category.
        if let m = mobility.first, let s = speed.first {
            if matchDayWorkSec(m) + matchDayWorkSec(s) <= budget { return [m, s] }
            let shorter = matchDayWorkSec(m) <= matchDayWorkSec(s) ? m : s
            let pool = (mobility + speed)
                .filter { $0.drill.id != shorter.drill.id }
                .sorted { matchDayWorkSec($0) < matchDayWorkSec($1) }
            if let partner = pool.first(where: { matchDayWorkSec(shorter) + matchDayWorkSec($0) <= budget }) ?? pool.first {
                return [shorter, partner]
            }
            return [shorter]
        }

        // Only one category available — take up to two, shortest unmastered-first.
        var picked: [DrillContext] = []
        var sec = 0
        for ctx in (mobility + speed) {
            guard picked.count < 2 else { break }
            if picked.isEmpty || sec + matchDayWorkSec(ctx) <= budget {
                picked.append(ctx)
                sec += matchDayWorkSec(ctx)
            }
        }
        return picked
    }

    /// Next mental exercise matching a predicate: the first unmastered one, else
    /// the first overall (rotate) so the slot always fills when content exists.
    private func nextMentalExercise(
        matching: (DrillContext) -> Bool,
        excluding: Set<String>
    ) -> DrillContext? {
        var candidates: [DrillContext] = []
        for discipline in disciplines {
            for category in sortedCategories(discipline) {
                for level in sortedLevels(category) {
                    for drill in sortedDrills(level) where drill.isMentalExercise {
                        let ctx = DrillContext(drill: drill, level: level, category: category, discipline: discipline)
                        if matching(ctx) && !excluding.contains(drill.id) {
                            candidates.append(ctx)
                        }
                    }
                }
            }
        }
        return candidates.first { !masteredDrillIDs.contains($0.drill.id) } ?? candidates.first
    }

    /// A personal pre-match cue line for the "You're ready" screen, built from the
    /// highest-rated Technical drill logged in the last 7 days, or a brave fallback.
    func matchDayCueLine(drillIndex: [String: DrillContext]) -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        let best = recentTechnicalRatings
            .filter { $0.date >= cutoff }
            .max { $0.rating < $1.rating }
        if let best, let ctx = drillIndex[best.drillID] {
            return "Trust your \(ctx.drill.focus.lowercased()) — you rated it \(best.rating)/5 this week."
        }
        return "Play brave. Play simple. Play YOUR game."
    }

    // MARK: - Sorting helpers

    private func sortedCategories(_ discipline: Discipline) -> [Category] {
        discipline.categories.sorted { $0.sortIndex < $1.sortIndex }
    }

    private func sortedLevels(_ category: Category) -> [MasteryLevel] {
        category.levels.sorted { $0.number < $1.number }
    }

    /// Levels of a category ordered so a brand-new plan starts near the player's
    /// reported level: levels at/above the starting bias come first (ascending),
    /// then any below it. Nothing is removed — lower levels stay reachable.
    private func biasedLevels(_ category: Category) -> [MasteryLevel] {
        let sorted = sortedLevels(category)
        guard startingLevelBias > 1 else { return sorted }
        let atOrAbove = sorted.filter { $0.number >= startingLevelBias }
        guard !atOrAbove.isEmpty else { return sorted }
        let below = sorted.filter { $0.number < startingLevelBias }
        return atOrAbove + below
    }

    private func sortedDrills(_ level: MasteryLevel) -> [Drill] {
        level.drills.sorted { $0.sortIndex < $1.sortIndex }
    }
}
