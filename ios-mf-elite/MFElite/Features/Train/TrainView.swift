import SwiftUI
import SwiftData

struct TrainView: View {
    @State private var showGenerate = false
    @State private var activeSession: TrainingQueue?
    @Query(sort: \Discipline.sortIndex) private var disciplines: [Discipline]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                    Text("Train")
                        .style(.hero)
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(.top, DS.Spacing.s64)
                        .padding(.bottom, DS.Spacing.s8)

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showGenerate = true
                    } label: {
                        MoreRow(icon: "dice", label: "Generate a session",
                                detail: "Pick time, focus & level — or Surprise me", isLast: false)
                    }
                    .buttonStyle(PressableButtonStyle())

                    NavigationLink(value: RoutinesRoute()) {
                        MoreRow(icon: "figure.run", label: "Routines",
                                detail: "Ready-made sessions", isLast: false)
                    }.buttonStyle(PressableButtonStyle())

                    NavigationLink(value: MyWorkoutsRoute()) {
                        MoreRow(icon: "hammer", label: "My Workouts",
                                detail: "Build your own", isLast: false)
                    }.buttonStyle(PressableButtonStyle())

                    NavigationLink(value: DrillLibraryRoute()) {
                        MoreRow(icon: "list.bullet", label: "Drill Library",
                                detail: "Every drill, by category", isLast: true)
                    }.buttonStyle(PressableButtonStyle())

                    CoachsChoiceSection()
                        .padding(.horizontal, -DS.Spacing.s20)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .navigationDestination(for: RoutinesRoute.self) { _ in RoutinesView() }
            .navigationDestination(for: MyWorkoutsRoute.self) { _ in MyWorkoutsView() }
            .navigationDestination(for: DrillLibraryRoute.self) { _ in DrillLibraryView() }
            .navigationDestination(for: FavoritesRoute.self) { _ in FavoritesView() }
            .fullScreenCover(item: $activeSession) { queue in SessionPlayerView(queue: queue) }
            .sheet(isPresented: $showGenerate) {
                GenerateSessionSheet { items in
                    showGenerate = false
                    guard !items.isEmpty else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        activeSession = TrainingQueue(items: items, source: .workout, sourceName: "Generated")
                    }
                }
                .presentationDetents([.large])
                .presentationBackground(DS.Colors.Bg.base)
            }
        }
    }
}
