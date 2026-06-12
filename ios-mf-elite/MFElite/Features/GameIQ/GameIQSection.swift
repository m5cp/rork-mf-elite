//
//  GameIQSection.swift
//  MFElite
//
//  The "GAME IQ" strip shown at the top of the Tactical discipline screen: a
//  horizontal list of concept-lesson cards, each showing a completed state once
//  the player has finished it. Tapping a card opens the full lesson player.
//

import SwiftUI
import SwiftData

struct GameIQSection: View {
    @Query(sort: \GameIQLesson.sortIndex) private var lessons: [GameIQLesson]

    @State private var activeLesson: GameIQLesson? = nil

    var body: some View {
        if !lessons.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SectionHead(eyebrow: "Game IQ", title: "Understand the game")
                    Spacer()
                    Eyebrow(text: "\(completedCount)/\(lessons.count)")
                }
                .padding(.horizontal, DS.Spacing.s20)

                Text("Short lessons that build your tactical brain — read, then test yourself.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.s12) {
                        ForEach(lessons) { lesson in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                activeLesson = lesson
                            } label: {
                                LessonCard(lesson: lesson)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.vertical, DS.Spacing.s4)
                }
                .padding(.top, DS.Spacing.s16)
            }
            .padding(.top, DS.Spacing.s24)
            .fullScreenCover(item: $activeLesson) { lesson in
                GameIQLessonView(lesson: lesson) {
                    activeLesson = nil
                }
            }
        }
    }

    private var completedCount: Int {
        lessons.filter { $0.isCompleted }.count
    }
}

// MARK: - LessonCard

private struct LessonCard: View {
    let lesson: GameIQLesson

    private var isCompleted: Bool { lesson.isCompleted }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                Spacer()
                if isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Done")
                            .style(.micro)
                    }
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                }
            }

            Text(lesson.title)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(lesson.summary)
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: DS.Spacing.s8) {
                Text("\(lesson.keyPoints.count) points")
                Text("·")
                Text("\(lesson.quiz.count) questions")
            }
            .style(.micro)
            .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .padding(DS.Spacing.s16)
        .frame(width: 220, height: 200, alignment: .topLeading)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(isCompleted ? DS.Colors.Line.strong : DS.Colors.Line.hairline, lineWidth: 1)
        )
    }
}
