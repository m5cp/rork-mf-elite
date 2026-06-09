//
//  HistoryCalendarView.swift
//  MFElite
//
//  A paged month calendar of training history. Each day cell shows a mini ring
//  cluster; tapping a day opens its detail. Days before the player installed the
//  app (no possible activity) render empty.
//

import SwiftUI
import SwiftData

/// Navigation route to the training history calendar.
struct WeeklyRoute: Hashable {}

struct HistoryCalendarView: View {
    @Query private var sessions: [SessionLogEntry]

    @State private var monthOffset = 0
    @State private var selectedDay: IdentifiableDate?

    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    /// Earliest day with any logged session — days before it render empty.
    private var firstActivityDay: Date? {
        sessions.map { calendar.startOfDay(for: $0.completedAt) }.min()
    }

    private var displayedMonth: Date {
        let base = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return calendar.date(byAdding: .month, value: monthOffset, to: base) ?? base
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                monthNav
                weekdayLabels
                monthGrid
                if sessions.isEmpty {
                    emptyState
                }
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedDay) { wrapped in
            DayDetailView(date: wrapped.date)
                .presentationDetents([.large])
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "History")
            Text("Training Calendar")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    private var monthNav: some View {
        HStack {
            IconButton(systemName: "chevron.left", size: 36) {
                withAnimation(DS.Motion.standardSpring) { monthOffset -= 1 }
            }
            Spacer()
            Text(monthTitle)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Spacer()
            IconButton(systemName: "chevron.right", size: 36) {
                guard monthOffset < 0 else { return }
                withAnimation(DS.Motion.standardSpring) { monthOffset += 1 }
            }
            .opacity(monthOffset < 0 ? 1 : 0.3)
            .disabled(monthOffset >= 0)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: displayedMonth)
    }

    private var weekdayLabels: some View {
        HStack(spacing: 6) {
            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { _ in
                EmptyView()
            }
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, label in
                Text(label)
                    .style(.microSm)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s20)
    }

    // MARK: - Grid

    private var monthGrid: some View {
        let cells = monthCells
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: DS.Spacing.s12) {
            ForEach(cells) { cell in
                if let date = cell.date {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 48)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
    }

    private func dayCell(_ date: Date) -> some View {
        let today = calendar.startOfDay(for: Date())
        let isFuture = date > today
        let beforeInstall: Bool = {
            guard let first = firstActivityDay else { return false }
            return date < first
        }()
        let rings = DailyRings.make(from: sessions, on: date, calendar: calendar)
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let dim = isFuture || beforeInstall

        return Button {
            selectedDay = IdentifiableDate(date: date)
        } label: {
            VStack(spacing: DS.Spacing.s4) {
                DayRingsView(rings: rings, size: 34, showCheckmarks: false)
                    .opacity(dim ? 0.25 : 1)
                    .overlay {
                        if isToday {
                            Circle().stroke(DS.Colors.Line.strong, lineWidth: 1.5)
                        }
                    }
                Text("\(calendar.component(.day, from: date))")
                    .style(.microSm)
                    .foregroundStyle(isToday ? DS.Colors.Ink.secondary : DS.Colors.Ink.quaternary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isFuture)
    }

    /// Cells for the displayed month, padded with leading blanks so the 1st lands
    /// under the correct weekday (Monday-first).
    private var monthCells: [CalendarCell] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [CalendarCell] = (0..<leadingBlanks).map { CalendarCell(id: -($0 + 1), date: nil) }
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(CalendarCell(id: day, date: date))
            }
        }
        return cells
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.s8) {
            Text("No training logged yet")
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.secondary)
            Text("Complete a drill to start filling your rings.")
                .style(.micro)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.s40)
    }

    private struct CalendarCell: Identifiable {
        let id: Int
        let date: Date?
    }
}

#Preview {
    NavigationStack {
        HistoryCalendarView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [
        Discipline.self, Category.self, MasteryLevel.self,
        Drill.self, DrillProgress.self, PlayerState.self, SessionLogEntry.self
    ])
}
