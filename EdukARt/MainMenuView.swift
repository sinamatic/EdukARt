import SwiftUI

struct MainMenuView: View {
    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var controller: RobotController
    @ObservedObject var gameMapStore: GameMapStore
    var onShowTutorial: () -> Void = {}

    var body: some View {
        ZStack {
            if DeviceLayout.isPad {
                IPadKeyvisualBackground()
            } else {
                Image("Keyvisual")
                    .resizable()
                    .scaledToFill()
            }

            VStack(spacing: 12) {
                NavigationLink {
                    StartGameView(
                        eduardModelStore: eduardModelStore,
                        controller: controller,
                        gameMapStore: gameMapStore
                    )
                } label: {
                    Text("Start Game")
                }
                .buttonStyle(MenuButtonStyle(color: Color("BrandGreen")))

                NavigationLink {
                    CoursesView(
                        eduardModelStore: eduardModelStore,
                        controller: controller,
                        gameMapStore: gameMapStore
                    )
                } label: {
                    Text("Courses")
                }
                .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay")))

                NavigationLink {
                    RobotRemoteView(controller: controller)
                } label: {
                    Text("Robot Remote")
                }
                .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay")))

                NavigationLink {
                    SettingsView(controller: controller)
                } label: {
                    Text("Settings")
                }
                .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay")))

                NavigationLink {
                    ScoresView(gameMapStore: gameMapStore)
                } label: {
                    Text("Scores")
                }
                .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay").opacity(0.72)))
                .padding(.top, 18)

                NavigationLink {
                    InfoView()
                } label: {
                    Text("Infos")
                }
                .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay")))
            }
            .padding(30)
            .padding(.bottom, 32)
            .frame(maxWidth: DeviceLayout.isPad ? 560 : .infinity)
        }
        .overlay(alignment: .topLeading) {
            Button(action: onShowTutorial) {
                Image(systemName: "questionmark")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.black.opacity(0.72))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.65), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .accessibilityLabel("Einführung öffnen")
            .padding(.top, 58)
            .padding(.leading, 30)
        }
        .overlay(alignment: .bottom) {
            MainMenuFooter()
                .padding(.bottom, 14)
                .allowsHitTesting(false)
        }
        .onAppear {
            controller.resetForManualControl()
        }
    }

    private struct MainMenuFooter: View {
        var body: some View {
            VStack(spacing: 4) {
                Text("© Sina Steinmüller")
                Text("www.sinamatic.de")
                if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                    Text("Version \(version)")
                }
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.8))
        }
    }

    private struct MenuButtonStyle: ButtonStyle {
        let color: Color

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .padding()
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

#Preview {
    MainMenuView(
        eduardModelStore: EduardModelStore(),
        controller: RobotController(),
        gameMapStore: GameMapStore()
    )
}
