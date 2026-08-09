//
//  CertificationsView.swift
//  MFElite
//
//  The skill certifications gallery — every category cert grouped by discipline.
//

import SwiftUI
import SwiftData

/// Navigation route to the certifications gallery.
struct CertificationsRoute: Hashable {}

struct CertificationsView: View {
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var progress: [DrillProgress]

    private var viewModel: CertificationsViewModel {
        CertificationsViewModel(
            disciplines: disciplines,
            masteredDrillIDs: Set(progress.filter { $0.isMastered }.map { $0.drillID })
        )
    }

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.s12),
        GridItem(.flexible(), spacing: DS.Spacing.s12)
    ]

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(vm)

                ForEach(Array(vm.disciplines.enumerated()), id: \.element.id) { index, discipline in
                    disciplineGroup(vm, discipline: discipline, isFirst: index == 0)
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ vm: CertificationsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtworkBanner(name: MFArtwork.certifications)
                .padding(.bottom, DS.Spacing.s12)

            Eyebrow(text: "Skill Certifications")
            Text("Certifications")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(.top, DS.Spacing.s8)
            Text("\(vm.earnedCount) of \(vm.totalCount) earned")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .padding(.top, DS.Spacing.s8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.Spacing.s16)
    }

    private func disciplineGroup(_ vm: CertificationsViewModel, discipline: Discipline, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.s8) {
                DisciplineMark(kind: discipline.mark, size: 16)
                Eyebrow(text: discipline.name)
            }

            LazyVGrid(columns: columns, spacing: DS.Spacing.s12) {
                ForEach(vm.categories(for: discipline)) { category in
                    CertTile(category: category, state: vm.certState(category))
                }
            }
            .padding(.top, DS.Spacing.s12)
        }
        .padding(.top, isFirst ? DS.Spacing.s24 : DS.Spacing.s24)
    }
}

// MARK: - Cert Tile

private struct CertTile: View {
    let category: Category
    let state: CertState

    var body: some View {
        VStack(spacing: 0) {
            CertSeal(size: 48, earned: state == .earned)

            Text(category.name)
                .style(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Colors.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.top, DS.Spacing.s8 + 2)

            stateLabel
                .padding(.top, DS.Spacing.s4 + 2)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.s16)
        .background(DS.Colors.Bg.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg - 4))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg - 4)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
        .opacity(opacity)
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch state {
        case .earned:
            HStack(spacing: DS.Spacing.s4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text("Earned")
                    .style(.micro)
            }
            .foregroundStyle(DS.Colors.Ink.primary)
        case .inProgress(let done, let total):
            Text("\(done)/\(total) Levels")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        case .notStarted:
            Text("Not Started")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        case .locked:
            HStack(spacing: DS.Spacing.s4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("Locked")
                    .style(.micro)
            }
            .foregroundStyle(DS.Colors.Ink.disabled)
        }
    }

    private var opacity: Double {
        switch state {
        case .earned: return 1
        case .locked: return 0.5
        default: return 0.7
        }
    }
}

#Preview {
    NavigationStack {
        CertificationsView()
            .preferredColorScheme(.dark)
            .modelContainer(for: [
                Discipline.self, Category.self, MasteryLevel.self,
                Drill.self, DrillProgress.self, PlayerState.self
            ])
    }
}
