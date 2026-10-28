import SwiftUI

struct ConsumentaCourseAccessView: View {
    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var controller: RobotController
    @ObservedObject var gameMapStore: GameMapStore

    @State private var password = ""
    @State private var isUnlocked = false
    @State private var showsWrongPassword = false

    var body: some View {
        if ConsumentaConfiguration.isEnabled == false || isUnlocked {
            CoursesView(
                eduardModelStore: eduardModelStore,
                controller: controller,
                gameMapStore: gameMapStore
            )
        } else {
            accessNotice
        }
    }

    private var accessNotice: some View {
        MapMenuBackground {
            MapMenuPanel {
                Text("Course creation disabled")
                    .mapMenuTitleStyle()

                Text("Course creation and editing are disabled during Consumenta so that you can focus on testing the game. If you are interested in creating courses or have ideas for better tracks, please fill out our survey.")
                    .mapMenuSubtitleStyle()

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .submitLabel(.done)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(unlockCourses)

                if showsWrongPassword {
                    Text("Incorrect password")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Unlock Course Editor", action: unlockCourses)
                    .buttonStyle(MapMenuButtonStyle(color: Color("BrandGreen")))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            controller.resetForManualControl()
        }
    }

    private func unlockCourses() {
        guard password == ConsumentaConfiguration.courseEditorPassword else {
            showsWrongPassword = true
            password = ""
            return
        }

        showsWrongPassword = false
        isUnlocked = true
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
