//
//  GlobalSearchView.swift
//  MFElite
//
//  Search anything, go straight there.
//
//  Every list in the app used to be its own island: the curriculum search only
//  found drills, the coach drill editor only found drills to edit, and there was
//  no way to find a screen at all — you had to remember which tab hid it.
//
//  This searches drills, routines, programs, combine tests, badges and every
//  screen in the app at once, and pushes the result inside its own
//  NavigationStack. Keeping the stack local means the five tab stacks don't have
//  to be rewired to accept an external path, and dismissing returns the player
//  exactly where they were.
//

import SwiftUI
import SwiftData

// MARK: - Result model

/// One thing the player can jump to.
struct GlobalSearchResult: Identifiable {
    enum Destination {
        case drill(DrillRoute)
        case level(LevelRoute)
        case category(CategoryRoute)
        case discipline(Discipline)
        /// A whole screen, pushed by its route value.
        case screen(AnyHashable)
        /// Switch to a tab and close search (used for Coach tools).
        case tab(AppTab)
    }

    let id: String
    let title: String
    /// "Technical · Ball Mastery · Level 2"
    let subtitle: String
    let icon: String
    let section: String
    let destination: Destination
    /// Extra words that should match but aren't displayed.
    let keywords: String

    func matches(_ query: String) -> Bool {
        title.lowercased().contains(query)
            || subtitle.lowercased().contains(query)
            || keywords.lowercased().contains(query)
    }
}

// MARK: - View

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscription
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]
    @Query(sort: \CombineTest.sortIndex) private var combineTests: [CombineTest]

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    /// Section order — screens first when the query is short, because a player
    /// typing two letters is usually looking for a place, not a specific drill.
    private static let sectionOrder = [
        "Screens", "Drills", "Combine", "Badges", "Coach"
    ]

    var body: some View {
        // Bound once per pass. `results` walks the whole curriculum, and body
        // needs it twice — for the empty check and for the list.
        let hits = results
        return NavigationStack {
            ZStack {
                DS.Colors.Bg.base.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchField

                    if trimmedQuery.isEmpty {
                        suggestions
                    } else if hits.isEmpty {
                        emptyState
                    } else {
                        resultsList(hits)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("SEARCH")
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.secondary)
                }
            }
            .navigationDestination(for: DrillRoute.self) { route in
                DrillDetailView(
                    drill: route.drill, level: route.level,
                    category: route.category, discipline: route.discipline
                )
            }
            .navigationDestination(for: LevelRoute.self) { route in
                LevelView(level: route.level, category: route.category, discipline: route.discipline)
            }
            .navigationDestination(for: CategoryRoute.self) { route in
                CategoryView(category: route.category, discipline: route.discipline)
            }
            .navigationDestination(for: Discipline.self) { discipline in
                DisciplineView(discipline: discipline)
            }
            .navigationDestination(for: ScreenRoute.self) { route in
                route.destination
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // A focus set during the cover's presentation transition is
            // dropped and the keyboard never rises, so wait it out. `.task`
            // rather than `asyncAfter` so tapping Done or a result inside the
            // delay cancels it instead of writing to a torn-down view.
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            searchFocused = true
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: DS.Spacing.s12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.Colors.Ink.quaternary)

            TextField(
                "",
                text: $query,
                prompt: Text("Drills, screens, badges, anything")
                    .foregroundColor(DS.Colors.Ink.quaternary)
            )
            .style(.body)
            .foregroundStyle(DS.Colors.Ink.primary)
            .focused($searchFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, DS.Spacing.s16)
        .frame(height: 48)
        .background(DS.Colors.Bg.raised)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1)
        )
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.bottom, DS.Spacing.s12)
    }

    // MARK: - States

    private var suggestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s8) {
                Eyebrow(text: "Jump to")
                    .padding(.horizontal, DS.Spacing.s20)
                    .padding(.bottom, DS.Spacing.s4)

                ForEach(quickJumps) { result in
                    row(result)
                }
            }
            .padding(.bottom, DS.Spacing.s32)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.s12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(DS.Colors.Ink.disabled)
            Text("Nothing matches “\(trimmedQuery)”")
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Try a drill name, a discipline, or a screen like “settings”.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.s32)
        .padding(.top, DS.Spacing.s48)
    }

    private func resultsList(_ hits: [GlobalSearchResult]) -> some View {
        // Grouped once. Filtering inside the ForEach re-ran the whole match
        // pass per section, per keystroke.
        let grouped = Dictionary(grouping: hits, by: { $0.section })
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Self.sectionOrder, id: \.self) { section in
                    let items = grouped[section] ?? []
                    if !items.isEmpty {
                        HStack {
                            Eyebrow(text: section)
                            Spacer(minLength: DS.Spacing.s8)
                            Text("\(items.count)")
                                .style(.micro)
                                .foregroundStyle(DS.Colors.Ink.quaternary)
                        }
                        .padding(.horizontal, DS.Spacing.s20)
                        .padding(.top, DS.Spacing.s16)
                        .padding(.bottom, DS.Spacing.s4)

                        ForEach(items) { row($0) }
                    }
                }
            }
            .padding(.bottom, DS.Spacing.s32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Row

    @ViewBuilder
    private func row(_ result: GlobalSearchResult) -> some View {
        switch result.destination {
        case .drill(let route):      link(result, value: route)
        case .level(let route):      link(result, value: route)
        case .category(let route):   link(result, value: route)
        case .discipline(let value): link(result, value: value)
        case .screen(let value):     link(result, value: ScreenRoute(id: result.id, wrapped: value))
        case .tab(let tab):
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                AppActionRouter.shared.pendingTab = tab
                dismiss()
            } label: {
                rowBody(result)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func link<V: Hashable>(_ result: GlobalSearchResult, value: V) -> some View {
        NavigationLink(value: value) { rowBody(result) }
            .buttonStyle(PressableButtonStyle())
    }

    private func rowBody(_ result: GlobalSearchResult) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            SectionIcon(systemName: result.icon, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .lineLimit(1)
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.vertical, DS.Spacing.s12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.title). \(result.subtitle)")
    }

    // MARK: - Data

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [GlobalSearchResult] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        // Cap drills so a one-letter query can't build 226 rows.
        var matched = allResults.filter { $0.matches(q) }
        if matched.count > 80 { matched = Array(matched.prefix(80)) }
        return matched
    }

    /// Shown before anything is typed — the places people actually hunt for.
    private var quickJumps: [GlobalSearchResult] {
        screenResults.filter {
            ["Settings", "Favorites", "My Workouts", "Routines", "Badges",
             "MF Combine", "Share Your Grind", "Progress"].contains($0.title)
        }
    }

    private var allResults: [GlobalSearchResult] {
        screenResults + drillResults + combineResults + badgeResults + coachResults
    }

    // MARK: Screens

    private var screenResults: [GlobalSearchResult] {
        func screen(
            _ title: String, _ subtitle: String, _ icon: String,
            _ route: AnyHashable, keywords: String = ""
        ) -> GlobalSearchResult {
            GlobalSearchResult(
                id: "screen-\(title)", title: title, subtitle: subtitle,
                icon: icon, section: "Screens",
                destination: .screen(route), keywords: keywords
            )
        }

        return [
            screen("Settings", "Account, notifications, accent, family safety", "gearshape",
                   SettingsRoute(), keywords: "preferences account notifications sound accent color passcode delete"),
            screen("Favorites", "Drills, routines and workouts you saved", "heart",
                   FavoritesRoute(), keywords: "saved hearted"),
            screen("My Workouts", "Workouts you built", "square.stack",
                   MyWorkoutsRoute(), keywords: "custom builder"),
            screen("Routines", "Curated training routines", "list.bullet.rectangle",
                   RoutinesRoute(), keywords: "sessions curated"),
            screen("Drill Library", "Every drill in the curriculum", "books.vertical",
                   DrillLibraryRoute(), keywords: "browse all drills curriculum"),
            screen("Programs", "Multi-week training programs", "calendar",
                   ProgramsRoute(), keywords: "plan block weeks"),
            screen("Badges", "Everything you've earned", "rosette",
                   BadgesRoute(), keywords: "achievements awards locker"),
            screen("Certifications", "Category certifications", "checkmark.seal",
                   CertificationsRoute(), keywords: "certificates seals"),
            screen("Academy Pathway", "Your rank and progression", "chart.line.uptrend.xyaxis",
                   ProgressionRoute(), keywords: "rank level xp pathway progression"),
            screen("MF Combine", "Your combine tests and scores", "stopwatch",
                   CombineRoute(), keywords: "tests sprint juggle benchmark scores"),
            screen("Share Your Grind", "Build a share card", "square.and.arrow.up",
                   ShareRoute(), keywords: "share cards instagram moments post"),
            screen("Player Card", "Your card", "person.text.rectangle",
                   PlayerCardRoute(), keywords: "card identity"),
            screen("Streak", "Your streak and freezes", "flame",
                   StreakRoute(), keywords: "streak freeze shield days"),
            screen("Progress", "History calendar and rings", "calendar.badge.clock",
                   WeeklyRoute(), keywords: "history calendar month rings"),
            screen("Proof of Progress", "How far you've come", "chart.bar",
                   ProofOfProgressRoute(), keywords: "improvement before after"),
            screen("Parent Report", "Monthly report for parents", "doc.text",
                   ParentReportRoute(), keywords: "parents report card monthly"),
            screen("Family", "Manage athletes on this device", "person.2",
                   FamilyRoute(), keywords: "athletes children add kid"),
            screen("MF Store", "XP packs, streak shields, boosters", "bag",
                   MFStoreRoute(), keywords: "buy purchase xp shield booster store"),
            screen("My Games", "Your fixtures", "sportscourt",
                   MyGamesRoute(), keywords: "games fixtures match schedule"),
            screen("Run Tracker", "Track a run", "figure.run",
                   RunTrackerRoute(), keywords: "run gps distance"),
            screen("Leaderboard", "Friends and global", "trophy",
                   FriendsLeaderboardRoute(), keywords: "friends global rank compare")
        ]
    }

    // MARK: Curriculum

    private var drillResults: [GlobalSearchResult] {
        var out: [GlobalSearchResult] = []
        for discipline in disciplines {
            out.append(
                GlobalSearchResult(
                    id: "disc-\(discipline.id)", title: discipline.name,
                    subtitle: "Discipline", icon: "square.grid.2x2",
                    section: "Drills", destination: .discipline(discipline),
                    keywords: "discipline pillar"
                )
            )
            for category in discipline.categories.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                out.append(
                    GlobalSearchResult(
                        id: "cat-\(category.id)", title: category.name,
                        subtitle: discipline.name, icon: "folder",
                        section: "Drills",
                        destination: .category(CategoryRoute(discipline: discipline, category: category)),
                        keywords: "category"
                    )
                )
                for level in category.levels.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                    out.append(
                        GlobalSearchResult(
                            id: "lvl-\(level.id)", title: level.name,
                            subtitle: "\(discipline.name) · \(category.name)",
                            icon: "chart.bar", section: "Drills",
                            destination: .level(
                                LevelRoute(discipline: discipline, category: category, level: level)
                            ),
                            keywords: "level \(level.number)"
                        )
                    )
                    for drill in level.drills.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                        out.append(
                            GlobalSearchResult(
                                id: "drill-\(drill.id)", title: drill.title,
                                subtitle: "\(discipline.name) · \(category.name) · Level \(level.number)",
                                icon: "figure.soccer", section: "Drills",
                                destination: .drill(
                                    DrillRoute(discipline: discipline, category: category,
                                               level: level, drill: drill)
                                ),
                                keywords: "\(drill.focus) drill"
                            )
                        )
                    }
                }
            }
        }
        return out
    }

    private var combineResults: [GlobalSearchResult] {
        combineTests.map { test in
            GlobalSearchResult(
                id: "combine-\(test.id)", title: test.name,
                subtitle: "Combine test", icon: "stopwatch", section: "Combine",
                destination: .screen(CombineRoute()),
                keywords: "combine test benchmark score \(test.unit)"
            )
        }
    }

    private var badgeResults: [GlobalSearchResult] {
        AchievementBadge.allCases.map { badge in
            GlobalSearchResult(
                id: "badge-\(badge.rawValue)", title: badge.title,
                subtitle: badge.detail, icon: badge.icon, section: "Badges",
                destination: .screen(BadgesRoute()),
                keywords: "badge achievement award"
            )
        }
    }

    private var coachResults: [GlobalSearchResult] {
        guard subscription.isCoach else { return [] }
        return [
            GlobalSearchResult(
                id: "coach-tab", title: "Coach Mode",
                subtitle: "Roster, workouts, announcements", icon: "person.3.fill",
                section: "Coach", destination: .tab(.coach),
                keywords: "coach roster team announcements workouts control center"
            )
        ]
    }
}

/// Wraps an arbitrary screen route so one `navigationDestination` can push any
/// of them. SwiftUI matches destinations by concrete type, and registering
/// twenty separate destinations here would duplicate what each tab already does.
struct ScreenRoute: Hashable {
    let id: String
    let wrapped: AnyHashable

    static func == (lhs: ScreenRoute, rhs: ScreenRoute) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    @MainActor @ViewBuilder
    var destination: some View {
        switch wrapped {
        case is SettingsRoute:            SettingsView()
        case is FavoritesRoute:           FavoritesView()
        case is MyWorkoutsRoute:          MyWorkoutsView()
        case is RoutinesRoute:            RoutinesView()
        case is DrillLibraryRoute:        DrillLibraryView()
        case is ProgramsRoute:            ProgramsView()
        case is BadgesRoute:              BadgesLockerView()
        case is CertificationsRoute:      CertificationsView()
        case is ProgressionRoute:         AcademyProgressionView()
        case is CombineRoute:             CombineView()
        case is ShareRoute:               MomentsGalleryView()
        case is PlayerCardRoute:          PlayerCardView()
        case is StreakRoute:              StreakDetailView()
        case is WeeklyRoute:              HistoryCalendarView()
        case is ProofOfProgressRoute:     ProofOfProgressView()
        case is ParentReportRoute:        ParentReportView()
        case is FamilyRoute:              FamilyManagementView()
        case is MFStoreRoute:             MFStoreView()
        case is MyGamesRoute:             MyGamesView()
        case is RunTrackerRoute:          RunTrackerView()
        case is FriendsLeaderboardRoute:  FriendsLeaderboardView()
        default:                          EmptyView()
        }
    }
}
