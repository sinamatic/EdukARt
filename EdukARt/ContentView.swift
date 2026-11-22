import SwiftUI

struct ContentView: View {
    @ObservedObject var eduardModelStore: EduardModelStore
    @StateObject private var robotController = RobotController()
    @StateObject private var gameMapStore = GameMapStore()

    @State private var showLogo = true
    @State private var tutorialStep: TutorialStep?

    var body: some View {
        ZStack {
            if showLogo {
                Image("EduArtSinamaticIcon")
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(0.6)
                    .ignoresSafeArea()
                    .task {
                        Task {
                            await eduardModelStore.load()
                        }
                        try? await Task.sleep(for: .seconds(2))
                        showLogo = false
                    }
            } else {
                NavigationStack {
                    MainMenuView(
                        eduardModelStore: eduardModelStore,
                        controller: robotController,
                        gameMapStore: gameMapStore,
                        onShowTutorial: { tutorialStep = .welcome }
                    )
                }
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
                .allowsHitTesting(tutorialStep == nil)
                .accessibilityHidden(tutorialStep != nil)

                if let tutorialStep {
                    TutorialView(
                        step: tutorialStep,
                        isWifiReachable: robotController.isWifiReachable,
                        isRobotEnabled: robotController.isEnabled,
                        onNext: {
                            self.tutorialStep = tutorialStep == .welcome ? .connection : .emergencyStop
                        },
                        onBack: {
                            self.tutorialStep = tutorialStep == .emergencyStop ? .connection : .welcome
                        },
                        onClose: { self.tutorialStep = nil }
                    )
                }

                RobotControlOverlay(
                    controller: robotController,
                    showsTutorialHint: tutorialStep == .emergencyStop,
                    onControlInteraction: {
                        if tutorialStep == .emergencyStop,
                           robotController.isWifiReachable,
                           robotController.isEnabled {
                            tutorialStep = nil
                        }
                    }
                )
            }
        }
        .overlayPreferenceValue(TutorialArrowAnchorsKey.self) { anchors in
            GeometryReader { geometry in
                if let icon = anchors[.powerIcon],
                   let button = anchors[.controlButton] {
                    TutorialPowerArrow(
                        icon: geometry[icon],
                        button: geometry[button]
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
        }
    }
}

private struct TutorialPowerArrow: View {
    let icon: CGRect
    let button: CGRect

    var body: some View {
        Path { path in
            let start = CGPoint(x: icon.maxX + 8, y: icon.midY)
            let turn = CGPoint(x: button.midX, y: start.y)
            let tip = CGPoint(x: button.midX, y: button.maxY + 8)

            path.move(to: start)
            path.addLine(to: turn)
            path.addLine(to: tip)
            path.move(to: CGPoint(x: tip.x - 8, y: tip.y + 10))
            path.addLine(to: tip)
            path.addLine(to: CGPoint(x: tip.x + 8, y: tip.y + 10))
        }
        .stroke(Color("BrandGreen"), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }
}

#Preview {
    ContentView(eduardModelStore: EduardModelStore())
}
