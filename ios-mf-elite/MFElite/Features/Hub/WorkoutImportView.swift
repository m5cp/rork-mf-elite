//
//  WorkoutImportView.swift
//  MFElite
//
//  Preview sheet for a shared workout decoded from a QR code or mfelite:// link.
//  Resolves the payload's drill IDs against the local curriculum, shows what will
//  be added, and saves a new CustomWorkout tagged "Shared". Unknown IDs (from a
//  newer curriculum version) are skipped with a clear note.
//

import SwiftUI
import SwiftData

struct WorkoutImportView: View {
    let payload: WorkoutShare.Payload

    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var indexCache = DrillIndexCache()
    @State private var didSave = false

    private var index: [String: ResolvedDrill] {
        buildDrillIndex(disciplines, cache: indexCache)
    }

    /// Drills from the payload that exist in this app's curriculum, in order.
    private var resolved: [ResolvedDrill] {
        payload.drills.compactMap { index[$0] }
    }

    private var unknownCount: Int {
        payload.drills.count - resolved.count
    }

    private var canImport: Bool {
        !resolved.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                    header

                    if canImport {
                        drillList
                        if unknownCount > 0 {
                            unknownNote
                        }
                    } else {
                        unsupportedCard
                    }
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s8)
                .padding(.bottom, DS.Spacing.s32)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                if canImport {
                    actionButtons
                        .padding(.horizontal, DS.Spacing.s20)
                        .padding(.bottom, DS.Spacing.s12)
                        .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Shared Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Workout shared with you")
            Text(payload.name)
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
            if canImport {
                Text("\(resolved.count) \(resolved.count == 1 ? "drill" : "drills") · ~\(estimatedMinutes(resolved)) min")
                    .style(.body)
                    .foregroundStyle(DS.Colors.Ink.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var drillList: some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(resolved.enumerated()), id: \.element.id) { idx, item in
                    HStack(spacing: DS.Spacing.s12) {
                        Text("\(idx + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .frame(width: 22, alignment: .center)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.drill.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ink.primary)
                            Text(item.category.name)
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, DS.Spacing.s12)
                    if idx < resolved.count - 1 {
                        Rectangle()
                            .fill(DS.Colors.Line.hairline)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private var unknownNote: some View {
        HStack(spacing: DS.Spacing.s8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
            Text("\(unknownCount) \(unknownCount == 1 ? "drill needs" : "drills need") a newer app version and will be skipped.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DS.Spacing.s4)
    }

    private var unsupportedCard: some View {
        Card(raised: true) {
            VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                Text("This workout needs a newer version of MF Elite")
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("None of its drills are available in your app yet. Update to the latest version and try scanning again.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: DS.Spacing.s8) {
            PrimaryButton(label: didSave ? "Added!" : "Add to My Workouts") {
                saveWorkout()
            }
            SecondaryButton(label: "Cancel") { dismiss() }
        }
        .padding(.top, DS.Spacing.s8)
    }

    private func saveWorkout() {
        guard canImport, !didSave else { return }
        let workout = CustomWorkout(
            title: payload.name,
            drillIDs: resolved.map(\.drill.id),
            isShared: true
        )
        context.insert(workout)
        try? context.save()
        SyncEngine.shared.enqueueCustomWorkout(workout)
        didSave = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}
