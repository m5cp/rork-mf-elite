//
//  ProgramScheduleSheet.swift
//  MFElite
//
//  Lets a player lay a program's training days across the upcoming weeks and add
//  them to their device calendar with reminders. Pick a start date and training
//  weekdays, preview the plan, then add it in one tap.
//

import SwiftUI

struct ProgramScheduleSheet: View {
    let program: TrainingProgram

    @Environment(\.dismiss) private var dismiss

    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var weekdays: Set<Int> = [2, 4, 6] // Mon / Wed / Fri
    @State private var hour = 17
    @State private var isAdding = false
    @State private var resultMessage: String?
    @State private var didSucceed = false

    /// Weekday symbols starting Sunday (1) … Saturday (7).
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var plan: [ScheduledTrainingDay] {
        ProgramScheduler.shared.plan(
            program: program,
            startDate: startDate,
            weekdays: weekdays,
            atHour: hour
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                    header

                    weekdaySection
                    timeSection
                    previewSection
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s16)
                .padding(.bottom, 140)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) { addBar }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
            }
            .alert(
                didSucceed ? "Added to calendar" : "Couldn\u{2019}t add",
                isPresented: Binding(
                    get: { resultMessage != nil },
                    set: { if !$0 { resultMessage = nil } }
                )
            ) {
                Button("Done") {
                    let success = didSucceed
                    resultMessage = nil
                    if success { dismiss() }
                }
            } message: {
                Text(resultMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Schedule")
            Text("Add \(program.title) to your calendar")
                .style(.title2)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Pick a start date and the days you train. We'll place \(program.totalDays) sessions on your calendar, each with a reminder. Rest days are skipped.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var weekdaySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(.white)
                .foregroundStyle(DS.Colors.Ink.primary)

            Eyebrow(text: "Training Days")
            HStack(spacing: DS.Spacing.s8) {
                ForEach(1...7, id: \.self) { weekday in
                    weekdayChip(weekday)
                }
            }
        }
    }

    private func weekdayChip(_ weekday: Int) -> some View {
        let selected = weekdays.contains(weekday)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if selected { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
        } label: {
            Text(dayLabels[weekday - 1])
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(selected ? DS.Colors.Ground.primary : DS.Colors.Ink.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(selected ? Color.white : DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(fullWeekdayName(weekday))
        .accessibilityvalueSelected(selected)
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Time Of Day")
            Picker("Time", selection: $hour) {
                ForEach([6, 7, 8, 9, 12, 15, 16, 17, 18, 19, 20], id: \.self) { h in
                    Text(hourLabel(h)).tag(h)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack {
                Eyebrow(text: "Preview")
                Spacer()
                Text("\(plan.count) sessions")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            if plan.isEmpty {
                Text("Pick at least one training day to see the schedule.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            } else {
                VStack(spacing: DS.Spacing.s8) {
                    ForEach(plan.prefix(8)) { day in
                        HStack(spacing: DS.Spacing.s12) {
                            Text(day.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.secondary)
                                .frame(width: 110, alignment: .leading)
                            Text(day.title)
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                    if plan.count > 8 {
                        Text("+ \(plan.count - 8) more")
                            .style(.micro)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var addBar: some View {
        VStack(spacing: 0) {
            PrimaryButton(
                label: isAdding ? "Adding\u{2026}" : "Add \(plan.count) sessions",
                hint: nil
            ) {
                addToCalendar()
            }
            .disabled(plan.isEmpty || isAdding)
            .opacity(plan.isEmpty || isAdding ? 0.5 : 1)
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s12)
            .padding(.bottom, DS.Spacing.s24)
        }
        .background(.ultraThinMaterial)
    }

    private func addToCalendar() {
        guard !isAdding else { return }
        isAdding = true
        let days = plan
        Task {
            let granted = await ProgramScheduler.shared.requestAccess()
            guard granted else {
                isAdding = false
                didSucceed = false
                resultMessage = "Calendar access is off. Turn it on in Settings to add your training schedule."
                return
            }
            let added = ProgramScheduler.shared.addToCalendar(days, programTitle: program.title)
            isAdding = false
            if added > 0 {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                didSucceed = true
                resultMessage = "\(added) training sessions are on your calendar, each with a reminder."
            } else {
                didSucceed = false
                resultMessage = "We couldn\u{2019}t add the events. Check that you have a default calendar set up."
            }
        }
    }

    private func hourLabel(_ h: Int) -> String {
        var components = DateComponents()
        components.hour = h
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.hour())
    }

    private func fullWeekdayName(_ weekday: Int) -> String {
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][weekday - 1]
    }
}

private extension View {
    /// Small accessibility helper to announce selection state on the day chips.
    func accessibilityvalueSelected(_ selected: Bool) -> some View {
        accessibilityValue(selected ? "Selected" : "Not selected")
    }
}
