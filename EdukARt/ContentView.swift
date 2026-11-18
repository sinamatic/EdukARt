//
//  ContentView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var eduardModelStore: EduardModelStore
    @StateObject private var robotController = RobotController()
    @StateObject private var gameMapStore = GameMapStore()

    @State private var showLogo = true
    @State private var tutorialStep: ConsumentaTutorialStep? = nil

    var body: some View {
        ZStack {
            if showLogo {
                Color.black
                    .ignoresSafeArea()

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
                    .background(SwipeBackDisabler())
                }
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
                .allowsHitTesting(tutorialStep == nil)
                .accessibilityHidden(tutorialStep != nil)

                if let tutorialStep {
                    ConsumentaTutorialView(
                        step: tutorialStep,
                        isWifiReachable: robotController.isWifiReachable,
                        onNext: {
                            self.tutorialStep = tutorialStep == .welcome ? .connection : .emergencyStop
                        },
                        onBack: {
                            self.tutorialStep = tutorialStep == .emergencyStop ? .connection : .welcome
                        },
                        onClose: { self.tutorialStep = nil }
                    )
                }

                // Keep the real controls above the tutorial so the final step
                // detects a tap even when no physical robot is connected.
                if robotController.isSpectatorModeActive == false {
                    RobotControlOverlay(
                        controller: robotController,
                        showsTutorialHint: tutorialStep == .emergencyStop,
                        onControlInteraction: {
                            if tutorialStep == .emergencyStop {
                                tutorialStep = nil
                            }
                        }
                    )
                }
            }
        }
    }
}

// Install at each navigation root so the policy covers every pushed screen.
private struct SwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackDisablingViewController {
        SwipeBackDisablingViewController()
    }

    func updateUIViewController(_ uiViewController: SwipeBackDisablingViewController, context: Context) {
        uiViewController.disableSwipeBack()
    }
}

private final class SwipeBackDisablingViewController: UIViewController {
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        disableSwipeBack()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        disableSwipeBack()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        disableSwipeBack()
    }

    func disableSwipeBack() {
        guard let navigationController else { return }
        block(navigationController.interactivePopGestureRecognizer)
        if #available(iOS 26.0, *) {
            block(navigationController.interactiveContentPopGestureRecognizer)
        }
    }

    private func block(_ gestureRecognizer: UIGestureRecognizer?) {
        // UIKit may re-enable recognizers after a push/pop. The delegate also
        // rejects recognition, while the standard back button remains usable.
        gestureRecognizer?.delegate = SwipeBackGestureBlocker.shared
        gestureRecognizer?.isEnabled = false
    }
}

private final class SwipeBackGestureBlocker: NSObject, UIGestureRecognizerDelegate {
    // Gesture delegates are weak; retain this policy for the app's lifetime.
    static let shared = SwipeBackGestureBlocker()

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}

#Preview {

    ContentView(
        eduardModelStore:
            EduardModelStore()
    )
}
