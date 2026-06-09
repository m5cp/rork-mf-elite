//
//  SeedData.swift
//  MFElite
//

import Foundation
import SwiftData

/// Seeds the full MF Elite curriculum and demo player state on first launch
/// by loading the bundled `curriculum.json` (158 drills across 19 categories).
enum SeedData {

    private static let seededCountKey = "MF_SEEDED_DRILL_COUNT"

    /// Inserts curriculum on first launch, and re-seeds the curriculum when the
    /// bundled drill count grows (an app update). Player progress is preserved
    /// because `DrillProgress` records are keyed by `drillID`, independent of the
    /// discipline graph that gets rebuilt.
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Discipline>())) ?? []

        guard let bundle = loadBundle() else {
            assertionFailure("curriculum.json missing or failed to decode")
            return
        }

        let bundleDrillCount = drillCount(in: bundle)

        if existing.isEmpty {
            // First launch — full seed.
            for discipline in bundle.disciplines.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                context.insert(buildDiscipline(discipline))
            }

            // Brand-new players start at zero — no streak, no XP, nothing mastered.
            // The bundled `demoPlayer` / `masteredDrillIDs` are intentionally ignored
            // so the app never ships pre-filled fake progress.
            let player = PlayerState(
                xp: 0,
                streak: 0,
                freezesRemaining: 0,
                lastTrainedDate: nil
            )
            context.insert(player)

            UserDefaults.standard.set(bundleDrillCount, forKey: seededCountKey)
            try? context.save()
            return
        }

        // Existing install — re-seed only if the curriculum has grown.
        let seededCount = UserDefaults.standard.integer(forKey: seededCountKey)
        guard bundleDrillCount > seededCount, seededCount > 0 else { return }

        // Curriculum expanded — replace the curriculum graph. Player progress
        // (DrillProgress, PlayerState) is preserved since it is stored separately.
        for discipline in existing {
            context.delete(discipline)
        }
        try? context.save()

        for discipline in bundle.disciplines.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            context.insert(buildDiscipline(discipline))
        }

        UserDefaults.standard.set(bundleDrillCount, forKey: seededCountKey)
        try? context.save()
    }

    /// Total number of drills across the bundled curriculum.
    private static func drillCount(in bundle: CurriculumBundle) -> Int {
        bundle.disciplines.reduce(0) { partial, discipline in
            partial + discipline.categories.reduce(0) { sub, category in
                sub + category.levels.reduce(0) { $0 + $1.drills.count }
            }
        }
    }

    // MARK: - Loading

    /// The daily motivation quotes shipped with the curriculum.
    static func dailyQuotes() -> [String] {
        loadBundle()?.dailyQuotes ?? []
    }

    private static func loadBundle() -> CurriculumBundle? {
        guard let url = Bundle.main.url(forResource: "curriculum", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(CurriculumBundle.self, from: data)
    }

    // MARK: - Model construction

    private static func buildDiscipline(_ dto: CurriculumBundle.DisciplineDTO) -> Discipline {
        Discipline(
            id: dto.id,
            number: dto.number,
            name: dto.name,
            mark: dto.mark,
            tagline: dto.tagline,
            blurb: dto.blurb,
            media: dto.media,
            sortIndex: dto.sortIndex,
            categories: dto.categories
                .sorted(by: { $0.sortIndex < $1.sortIndex })
                .map(buildCategory)
        )
    }

    private static func buildCategory(_ dto: CurriculumBundle.CategoryDTO) -> Category {
        Category(
            id: dto.id,
            letter: dto.letter,
            name: dto.name,
            focus: dto.focus,
            certName: dto.certName,
            sortIndex: dto.sortIndex,
            levels: dto.levels
                .sorted(by: { $0.sortIndex < $1.sortIndex })
                .map(buildLevel)
        )
    }

    private static func buildLevel(_ dto: CurriculumBundle.LevelDTO) -> MasteryLevel {
        MasteryLevel(
            id: dto.id,
            number: dto.number,
            name: dto.name,
            theme: dto.theme,
            sortIndex: dto.sortIndex,
            drills: dto.drills
                .sorted(by: { $0.sortIndex < $1.sortIndex })
                .map(buildDrill)
        )
    }

    private static func buildDrill(_ dto: CurriculumBundle.DrillDTO) -> Drill {
        Drill(
            id: dto.id,
            title: dto.title,
            focus: dto.focus,
            how: dto.how,
            videoURL: dto.videoURL,
            durationSec: dto.durationSec,
            sets: dto.sets,
            coachingPoints: dto.coachingPoints,
            instructions: dto.instructions ?? [],
            sortIndex: dto.sortIndex,
            exerciseKind: dto.exerciseKind,
            steps: dto.steps ?? [],
            journalPrompt: dto.journalPrompt,
            equipment: dto.equipment ?? [],
            space: dto.space
        )
    }
}

// MARK: - Codable DTOs (decoded off the model actor)

/// The decoded shape of the bundled `curriculum.json`.
nonisolated struct CurriculumBundle: Codable {
    let dailyQuotes: [String]
    let demoPlayer: DemoPlayerDTO
    let masteredDrillIDs: [String]
    let disciplines: [DisciplineDTO]

    nonisolated struct DemoPlayerDTO: Codable {
        let xp: Int
        let streak: Int
        let freezes: Int
    }

    nonisolated struct DisciplineDTO: Codable {
        let id: String
        let number: String
        let name: String
        let mark: String
        let tagline: String
        let blurb: String
        let media: String
        let sortIndex: Int
        let categories: [CategoryDTO]
    }

    nonisolated struct CategoryDTO: Codable {
        let id: String
        let letter: String
        let name: String
        let focus: String
        let certName: String
        let sortIndex: Int
        let levels: [LevelDTO]
    }

    nonisolated struct LevelDTO: Codable {
        let id: String
        let number: Int
        let name: String
        let theme: String
        let sortIndex: Int
        let drills: [DrillDTO]
    }

    nonisolated struct DrillDTO: Codable {
        let id: String
        let title: String
        let focus: String
        let how: String
        let videoURL: String?
        let durationSec: Int
        let sets: Int
        let coachingPoints: [String]
        let instructions: [String]?
        let sortIndex: Int
        let exerciseKind: String?
        let steps: [String]?
        let journalPrompt: String?
        let equipment: [String]?
        let space: String?
    }
}
