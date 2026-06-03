//
//  CoachBuildSessionView.swift
//  MFElite
//
//  Build a custom training session from the drill library.
//

import SwiftUI
import SwiftData

struct CoachBuildSessionView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @State private var selectedIDs: Set<String> = []

    /// All drills flattened with their parent discipline, in curriculum order.
    private var allDrills: [(drill: Drill, discipline: Discipline)] {
        disciplines.flatMap { discipline in
            discipline.categories
                .sorted { $0.sortIndex < $1.sortIndex }
                .flatMap { $0.levels.sorted { $0.sortIndex < $1.sortIndex } }
                .flatMap { $0.drills.sorted { $0.sortIndex < $1.sortIndex } }
                .map { ($0, discipline) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if !selectedIDs.isEmpty { sessionCard }
                drillList
            }
            .padding(.bottom, 140)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(label: "Start session", hint: "\(selectedIDs.count) DRILLS") {}
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s12)
                .opacity(selectedIDs.isEmpty ? 0.5 : 1)
                .disabled(selectedIDs.isEmpty)
                .background(
                    LinearGradient(
                        colors: [DS.Colors.Bg.base.opacity(0), DS.Colors.Bg.base],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Build")
            Text("Session Builder")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    private var sessionCard: some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                HStack {
                    Eyebrow(text: "Session Lineup")
                    Spacer()
                    Text("\(selectedIDs.count)")
                        .font(DS.Typography.num(size: 18))
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
                ForEach(selectedDrills, id: \.drill.id) { item in
                    HStack(spacing: DS.Spacing.s8) {
                        DisciplineMark(kind: item.discipline.mark, size: 14)
                        Text(item.drill.title)
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private var selectedDrills: [(drill: Drill, discipline: Discipline)] {
        allDrills.filter { selectedIDs.contains($0.drill.id) }
    }

    private var drillList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Drill Library")
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s32)
                .padding(.bottom, DS.Spacing.s8)

            ForEach(Array(allDrills.enumerated()), id: \.element.drill.id) { index, item in
                drillRow(item)
                if index != allDrills.count - 1 {
                    Hairline().padding(.horizontal, DS.Spacing.s20)
                }
            }
        }
    }

    private func drillRow(_ item: (drill: Drill, discipline: Discipline)) -> some View {
        let selected = selectedIDs.contains(item.drill.id)
        return Button {
            toggle(item.drill.id)
        } label: {
            HStack(spacing: DS.Spacing.s16) {
                DisciplineMark(kind: item.discipline.mark, size: 20)
                    .frame(width: 40, height: 40)
                    .background(DS.Colors.Bg.card)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .stroke(DS.Colors.Line.hairline, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.drill.title)
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .lineLimit(1)
                    Text(item.discipline.name)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(selected ? Color.white : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle().stroke(
                                selected ? Color.white : DS.Colors.Line.subtle,
                                lineWidth: 1
                            )
                        )
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                    }
                }
            }
            .padding(.vertical, DS.Spacing.s12)
            .padding(.horizontal, DS.Spacing.s20)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}

#Preview {
    NavigationStack {
        CoachBuildSessionView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [
        Discipline.self, Category.self, MasteryLevel.self,
        Drill.self, DrillProgress.self, PlayerState.self
    ])
}
