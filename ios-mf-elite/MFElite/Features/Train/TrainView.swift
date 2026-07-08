import SwiftUI
import SwiftData

struct TrainView: View {
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

                    CoachsChoiceSection()
                        .padding(.horizontal, -DS.Spacing.s20)

                    NavigationLink(value: RoutinesRoute()) {
                        MoreRow(icon: "figure.run", label: "Routines",
                                detail: "Ready-made sessions — pick one and go", isLast: false)
                    }.buttonStyle(PressableButtonStyle())

                    NavigationLink(value: MyWorkoutsRoute()) {
                        MoreRow(icon: "hammer", label: "My Plan",
                                detail: "Build your own workout", isLast: true)
                    }.buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, 120)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .navigationDestination(for: RoutinesRoute.self) { _ in RoutinesView() }
            .navigationDestination(for: MyWorkoutsRoute.self) { _ in MyWorkoutsView() }
            .navigationDestination(for: FavoritesRoute.self) { _ in FavoritesView() }
            .fullScreenCover(item: $activeSession) { queue in SessionPlayerView(queue: queue) }
        }
    }
}
