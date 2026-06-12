//
//  GameIQLesson.swift
//  MFElite
//
//  A short tactical "Game IQ" concept lesson: a few key points shown one per
//  screen, followed by a 3-question quiz. Lessons deepen a Tactical category and
//  are keyed by a stable id so they survive re-seeds. First-ever completion
//  awards XP once and counts toward the day's Tactical training.
//

import Foundation
import SwiftData

@Model
final class GameIQLesson {
    @Attribute(.unique) var id: String
    var title: String
    var summary: String         // 2–3 sentences, shown on the card
    var keyPoints: [String]     // one per step screen
    var quizData: Data          // JSON-encoded [QuizQuestion]
    var relatedCategoryID: String   // tactical category this lesson deepens
    var sortIndex: Int
    var completedAt: Date?

    /// One multiple-choice quiz question with an explanation shown after answering.
    nonisolated struct QuizQuestion: Codable {
        var prompt: String
        var choices: [String]   // 3 choices
        var correctIndex: Int
        var whyText: String     // shown after answering, right or wrong
    }

    /// The decoded quiz questions. Empty if the stored data can't be decoded.
    var quiz: [QuizQuestion] {
        (try? JSONDecoder().decode([QuizQuestion].self, from: quizData)) ?? []
    }

    /// Convenience for building lessons from in-memory question arrays.
    static func encode(_ questions: [QuizQuestion]) -> Data {
        (try? JSONEncoder().encode(questions)) ?? Data()
    }

    var isCompleted: Bool { completedAt != nil }

    init(
        id: String,
        title: String,
        summary: String,
        keyPoints: [String],
        quizData: Data,
        relatedCategoryID: String,
        sortIndex: Int,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.keyPoints = keyPoints
        self.quizData = quizData
        self.relatedCategoryID = relatedCategoryID
        self.sortIndex = sortIndex
        self.completedAt = completedAt
    }
}
