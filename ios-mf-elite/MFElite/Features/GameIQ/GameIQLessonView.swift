//
//  GameIQLessonView.swift
//  MFElite
//
//  The Game IQ lesson player: a short concept lesson shown one key point per
//  screen, then a 3-question quiz with instant feedback, then a completion
//  screen. First-ever completion awards XP once and credits the Tactical rings.
//

import SwiftUI
import SwiftData

struct GameIQLessonView: View {
    let lesson: GameIQLesson
    var onClose: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var stage: Stage = .intro
    @State private var pointIndex: Int = 0
    @State private var questionIndex: Int = 0
    @State private var selectedChoice: Int? = nil
    @State private var correctCount: Int = 0
    @State private var outcome: GameIQStore.Outcome? = nil

    private enum Stage {
        case intro
        case points
        case quiz
        case complete
    }

    private var keyPoints: [String] { lesson.keyPoints }
    private var quiz: [GameIQLesson.QuizQuestion] { lesson.quiz }
    private var wasCompletedBefore: Bool { lesson.isCompleted }

    var body: some View {
        ZStack {
            DS.Colors.Bg.base.ignoresSafeArea()

            switch stage {
            case .intro:    introStage
            case .points:   pointsStage
            case .quiz:     quizStage
            case .complete: completeStage
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private func header(showProgress: Bool, total: Int, index: Int) -> some View {
        VStack(spacing: DS.Spacing.s16) {
            HStack {
                IconButton(systemName: "xmark", size: 36) { onClose() }
                Spacer()
                Eyebrow(text: "Game IQ")
                Spacer()
                DisciplineMark(kind: "diamond", size: 24)
            }

            if showProgress {
                HStack(spacing: 4) {
                    ForEach(0..<max(total, 1), id: \.self) { idx in
                        Capsule()
                            .fill(idx <= index ? Color.white : DS.Colors.Line.subtle)
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                            .animation(DS.Motion.standardSpring, value: index)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    // MARK: - Intro

    private var introStage: some View {
        VStack(spacing: 0) {
            header(showProgress: false, total: 0, index: 0)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: DS.Spacing.s8) {
                        lessonBadge
                        infoPill("\(keyPoints.count) points")
                        infoPill("\(quiz.count)-question quiz")
                        if !wasCompletedBefore {
                            infoPill("+\(GameIQStore.xpReward) XP")
                        }
                    }

                    Text(lesson.title)
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(.top, DS.Spacing.s20)

                    Text(lesson.summary)
                        .style(.body)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .padding(.top, DS.Spacing.s16)

                    if wasCompletedBefore {
                        HStack(spacing: DS.Spacing.s8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                            Text("You've completed this lesson. Reviewing won't earn XP again.")
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                        }
                        .padding(.top, DS.Spacing.s20)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)

            FloatingButton(label: wasCompletedBefore ? "Review lesson" : "Start lesson", hint: "\(keyPoints.count) POINTS") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(DS.Motion.standardSpring) { stage = .points }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s40)
        }
    }

    private var lessonBadge: some View {
        HStack(spacing: DS.Spacing.s4 + 2) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 11, weight: .bold))
            Text("Lesson")
                .style(.micro)
        }
        .foregroundStyle(DS.Colors.Ground.primary)
        .padding(.vertical, 6)
        .padding(.horizontal, DS.Spacing.s12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }

    private func infoPill(_ text: String) -> some View {
        Text(text)
            .style(.micro)
            .foregroundStyle(DS.Colors.Ink.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, DS.Spacing.s12 + 2)
            .background(DS.Colors.Bg.raised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }

    // MARK: - Key points

    private var pointsStage: some View {
        VStack(spacing: 0) {
            header(showProgress: true, total: keyPoints.count, index: pointIndex)

            Spacer(minLength: 0)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Eyebrow(text: "Point \(pointIndex + 1) of \(keyPoints.count)")
                        .foregroundStyle(DS.Colors.Ink.quaternary)

                    Text(keyPoints.indices.contains(pointIndex) ? keyPoints[pointIndex] : "")
                        .style(.title2)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(DS.Motion.standardSpring, value: pointIndex)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s24)
                .padding(.bottom, DS.Spacing.s24)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: DS.Spacing.s12) {
                if pointIndex > 0 {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(DS.Motion.standardSpring) { pointIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(DS.Colors.Line.subtle, lineWidth: 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                FloatingButton(label: pointIndex < keyPoints.count - 1 ? "Next" : "Take the quiz") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if pointIndex < keyPoints.count - 1 {
                        withAnimation(DS.Motion.standardSpring) { pointIndex += 1 }
                    } else {
                        withAnimation(DS.Motion.standardSpring) { stage = .quiz }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s40)
        }
    }

    // MARK: - Quiz

    private var currentQuestion: GameIQLesson.QuizQuestion? {
        quiz.indices.contains(questionIndex) ? quiz[questionIndex] : nil
    }

    private var hasAnswered: Bool { selectedChoice != nil }

    private var quizStage: some View {
        VStack(spacing: 0) {
            header(showProgress: true, total: quiz.count, index: questionIndex)

            if let question = currentQuestion {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                        Eyebrow(text: "Question \(questionIndex + 1) of \(quiz.count)")
                            .foregroundStyle(DS.Colors.Ink.quaternary)

                        Text(question.prompt)
                            .style(.title2)
                            .foregroundStyle(DS.Colors.Ink.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: DS.Spacing.s12) {
                            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                                choiceRow(question: question, index: index, choice: choice)
                            }
                        }

                        if hasAnswered {
                            whyCard(question: question)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.top, DS.Spacing.s24)
                    .padding(.bottom, DS.Spacing.s24)
                }
                .scrollIndicators(.hidden)

                FloatingButton(label: questionIndex < quiz.count - 1 ? "Continue" : "Finish lesson") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    advanceQuiz()
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s40)
                .opacity(hasAnswered ? 1 : 0.4)
                .disabled(!hasAnswered)
                .animation(DS.Motion.standardSpring, value: hasAnswered)
            }
        }
    }

    private func choiceRow(question: GameIQLesson.QuizQuestion, index: Int, choice: String) -> some View {
        let isSelected = selectedChoice == index
        let isCorrect = index == question.correctIndex
        let revealed = hasAnswered

        let borderColor: Color = {
            guard revealed else { return DS.Colors.Line.subtle }
            if isCorrect { return Self.correctColor }
            if isSelected { return Self.wrongColor }
            return DS.Colors.Line.subtle
        }()

        let fill: Color = {
            guard revealed else { return DS.Colors.Bg.card }
            if isCorrect { return Self.correctColor.opacity(0.14) }
            if isSelected { return Self.wrongColor.opacity(0.14) }
            return DS.Colors.Bg.card
        }()

        return Button {
            guard !hasAnswered else { return }
            selectChoice(index, question: question)
        } label: {
            HStack(spacing: DS.Spacing.s12) {
                Text(choice)
                    .style(.callout)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                if revealed && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Self.correctColor)
                } else if revealed && isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Self.wrongColor)
                }
            }
            .padding(.vertical, DS.Spacing.s16)
            .padding(.horizontal, DS.Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(borderColor, lineWidth: revealed && (isCorrect || isSelected) ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(hasAnswered)
    }

    private func whyCard(question: GameIQLesson.QuizQuestion) -> some View {
        let wasCorrect = selectedChoice == question.correctIndex
        return VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            HStack(spacing: DS.Spacing.s8) {
                Image(systemName: wasCorrect ? "checkmark.seal.fill" : "lightbulb.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(wasCorrect ? Self.correctColor : DS.Colors.Ink.primary)
                Eyebrow(text: wasCorrect ? "Correct" : "Here's why", color: wasCorrect ? Self.correctColor : DS.Colors.Ink.tertiary)
            }
            Text(question.whyText)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.s16)
        .background(DS.Colors.Bg.elevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func selectChoice(_ index: Int, question: GameIQLesson.QuizQuestion) {
        selectedChoice = index
        let correct = index == question.correctIndex
        if correct {
            correctCount += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        withAnimation(DS.Motion.standardSpring) {}
    }

    private func advanceQuiz() {
        if questionIndex < quiz.count - 1 {
            withAnimation(DS.Motion.standardSpring) {
                questionIndex += 1
                selectedChoice = nil
            }
        } else {
            finish()
        }
    }

    // MARK: - Completion

    private func finish() {
        let result = GameIQStore.complete(lesson, context: modelContext)
        outcome = result
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(DS.Motion.standardSpring) { stage = .complete }
    }

    private var completeStage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: DS.Spacing.s20) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 140, height: 140)
                        .blur(radius: 30)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                Eyebrow(text: "Lesson Complete")

                Text(lesson.title)
                    .style(.title1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.horizontal, DS.Spacing.s24)

                Text("You scored \(correctCount) of \(quiz.count) on the quiz.")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)

                if let outcome, outcome.xpAwarded > 0 {
                    rewardPill("+\(outcome.xpAwarded) XP", icon: "bolt.fill")
                } else {
                    Text("Reviewed — no extra XP this time.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
            }

            Spacer()

            FloatingButton(label: "Done") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onClose()
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, DS.Spacing.s40)
        }
    }

    private func rewardPill(_ text: String, icon: String) -> some View {
        HStack(spacing: DS.Spacing.s8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
            Text(text)
                .style(.title3)
        }
        .foregroundStyle(DS.Colors.Ground.primary)
        .padding(.vertical, DS.Spacing.s12)
        .padding(.horizontal, DS.Spacing.s24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
    }

    // MARK: - Quiz feedback colors

    private static let correctColor = Color(red: 0.30, green: 0.78, blue: 0.47)
    private static let wrongColor = Color(red: 0.90, green: 0.36, blue: 0.36)
}
