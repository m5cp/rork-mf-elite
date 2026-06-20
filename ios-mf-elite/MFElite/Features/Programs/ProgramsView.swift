import SwiftUI
import SwiftData

struct ProgramsRoute: Hashable {}

struct ProgramsView: View {
    @Query private var enrollments: [ProgramEnrollment]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s16) {
                Text("Programs")
                    .style(.display)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s24)

                ForEach(ProgramCatalog.all) { program in
                    NavigationLink(value: program) {
                        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                            Eyebrow(text: "\(program.tag) · \(program.weeks.count) WEEKS")
                            Text(program.title).style(.title2).foregroundStyle(DS.Colors.Ink.primary)
                            Text(program.blurb).style(.foot).foregroundStyle(DS.Colors.Ink.tertiary)
                            if let e = enrollments.first(where: { $0.programID == program.id }) {
                                Text("\(e.completedDayKeys.count)/\(program.totalDays) days done")
                                    .style(.micro).foregroundStyle(DS.Colors.Ink.secondary)
                            }
                        }
                        .padding(DS.Spacing.s16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Colors.Bg.card)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationDestination(for: TrainingProgram.self) { ProgramDetailView(program: $0) }
    }
}

struct ProgramDetailView: View {
    let program: TrainingProgram

    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query private var enrollments: [ProgramEnrollment]
    @Environment(\.modelContext) private var context

    @State private var indexCache = DrillIndexCache()
    @State private var activeSession: TrainingQueue?
    @State private var pendingKey: String?
    @State private var showSchedule = false

    private var enrollment: ProgramEnrollment? { enrollments.first { $0.programID == program.id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                Text(program.title).style(.title1).foregroundStyle(DS.Colors.Ink.primary)
                    .padding(.top, DS.Spacing.s24)

                Button { showSchedule = true } label: {
                    HStack(spacing: DS.Spacing.s12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.Colors.Ground.primary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Schedule in calendar")
                                .style(.callout).fontWeight(.bold)
                                .foregroundStyle(DS.Colors.Ground.primary)
                            Text("\(program.totalDays) sessions with reminders")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ground.primary.opacity(0.7))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Colors.Ground.primary.opacity(0.6))
                    }
                    .padding(DS.Spacing.s16)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(PressableButtonStyle())

                ForEach(Array(program.weeks.enumerated()), id: \.offset) { wIdx, week in
                    VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                        Eyebrow(text: week.title)
                        ForEach(Array(week.days.enumerated()), id: \.offset) { dIdx, day in
                            dayRow(week: wIdx, dayIndex: dIdx, day: day)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .fullScreenCover(item: $activeSession, onDismiss: markPendingComplete) { q in
            SessionPlayerView(queue: q)
        }
        .sheet(isPresented: $showSchedule) {
            ProgramScheduleSheet(program: program)
                .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private func dayRow(week: Int, dayIndex: Int, day: ProgramDay) -> some View {
        let key = ProgramEnrollment.key(week: week, day: dayIndex)
        let done = enrollment?.completedDayKeys.contains(key) ?? false
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: done ? "checkmark.circle.fill" : (day.isRest ? "moon.zzz" : "circle"))
                .foregroundStyle(done ? DS.Colors.Ink.primary : DS.Colors.Ink.quaternary)
            Text(day.title).style(.callout).foregroundStyle(DS.Colors.Ink.secondary)
            Spacer(minLength: 0)
            if !day.isRest {
                Button(done ? "Again" : "Start") { start(day: day, key: key) }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.Colors.Ground.primary)
                    .padding(.vertical, 6).padding(.horizontal, 14)
                    .background(Color.white).clipShape(Capsule())
                    .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.vertical, DS.Spacing.s8)
    }

    private func start(day: ProgramDay, key: String) {
        let index = buildDrillIndex(disciplines, cache: indexCache)
        let items = day.drillIDs.compactMap { index[$0]?.context }
        guard !items.isEmpty else { return }
        pendingKey = key
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        activeSession = TrainingQueue(items: items, source: .workout, sourceName: program.title)
    }

    /// On returning from the session, mark that day complete.
    private func markPendingComplete() {
        guard let key = pendingKey else { return }
        pendingKey = nil
        let e = enrollment ?? {
            let new = ProgramEnrollment(programID: program.id)
            context.insert(new); return new
        }()
        if !e.completedDayKeys.contains(key) { e.completedDayKeys.append(key) }
        try? context.save()
    }
}
