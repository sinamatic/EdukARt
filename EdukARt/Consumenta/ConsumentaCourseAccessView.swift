import SwiftUI

struct ConsumentaCourseAccessView: View {
    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var controller: RobotController
    @ObservedObject var gameMapStore: GameMapStore

    var body: some View {
        CoursesView(
            eduardModelStore: eduardModelStore,
            controller: controller,
            gameMapStore: gameMapStore
        )
    }
}

#Preview {
    NavigationStack {
        ConsumentaCourseAccessView(
            eduardModelStore: EduardModelStore(),
            controller: RobotController(),
            gameMapStore: GameMapStore()
        )
    }
}
