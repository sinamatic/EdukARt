//
//  ContentView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI
import UIKit

struct ContentView: View {

    @ObservedObject var eduardModelStore:
        EduardModelStore

    @StateObject private var robotController =
        RobotController()
    
    @StateObject private var gameMapStore =
        GameMapStore()

    @State private var showLogo = true

    @State private var tutorialStep: ConsumentaTutorialStep? =
        ConsumentaConfiguration.isEnabled ? .welcome : nil

    @State private var tutorialMap: GameMap?

    @State private var selectedTutorialMap: GameMap?

    @State private var isTutorialMapLocalized = false


    var body: some View {

        ZStack {
        if showLogo {

            Color.black
                .ignoresSafeArea()

            Image(
                "EduArtSinamaticIcon"
            )
            .resizable()
            .scaledToFit()
            .scaleEffect(0.6)
            .ignoresSafeArea()
            .task {

                Task {
                    await eduardModelStore.load()
                }

                try? await Task.sleep(
                    for:
                        .seconds(2)
                )

                showLogo =
                    false
            }

        } else {
            
            
                
                tutorialBackground
                .ignoresSafeArea()
                .preferredColorScheme(
                    .dark
                )
            }
            
            if showLogo == false
                && robotController.isSpectatorModeActive == false {
                RobotControlOverlay(
                               controller:
                                   robotController
                           )
                       }

            if let tutorialStep {
                ConsumentaTutorialView(
                    step: tutorialStep,
                    canAdvance: canAdvanceTutorial,
                    onNext: advanceTutorial,
                    onBack: goBackInTutorial,
                    onClose: closeTutorial
                )
            }

                
                
        }
    }

    @ViewBuilder
    private var tutorialBackground: some View {
        if tutorialStep == .courseSelection {
            NavigationStack {
                StartGameView(
                    eduardModelStore: eduardModelStore,
                    controller: robotController,
                    gameMapStore: gameMapStore,
                    onTutorialGameStart: startTutorialGame,
                    onTutorialMapSelection: { selectedTutorialMap = $0 }
                )
                .background(SwipeBackDisabler())
            }
            .preferredColorScheme(.dark)
        } else if let tutorialMap,
                  tutorialStep == .mapLocalization
                    || tutorialStep == .arStart
                    || tutorialStep == .arControls
                    || tutorialStep == .gameGoal {
            GameView(
                map: tutorialMap,
                eduardModelStore: eduardModelStore,
                controller: robotController,
                onTutorialMapLocalized: tutorialMapLocalized,
                tutorialTopPadding: 44
            )
            .preferredColorScheme(.dark)
        } else {
            NavigationStack {
                MainMenuView(
                    eduardModelStore: eduardModelStore,
                    controller: robotController,
                    gameMapStore: gameMapStore,
                    onShowTutorial: startTutorial
                )
                .background(SwipeBackDisabler())
            }
            .preferredColorScheme(.dark)
        }
    }

    private func startTutorial() {
        tutorialMap = nil
        selectedTutorialMap = nil
        isTutorialMapLocalized = false
        tutorialStep = .welcome
    }

    private func closeTutorial() {
        tutorialMap = nil
        selectedTutorialMap = nil
        isTutorialMapLocalized = false
        tutorialStep = nil
    }

    private func startTutorialGame(_ map: GameMap) {
        tutorialMap = map
        isTutorialMapLocalized = false
        tutorialStep = .mapLocalization
    }

    private func tutorialMapLocalized() {
        isTutorialMapLocalized = true

        if tutorialStep == .mapLocalization {
            tutorialStep = .arStart
        }
    }

    private var canAdvanceTutorial: Bool {
        switch tutorialStep {
        case .mapLocalization:
            isTutorialMapLocalized
        case .courseSelection:
            selectedTutorialMap != nil
        default:
            true
        }
    }

    private func advanceTutorial() {
        switch tutorialStep {
        case .welcome: tutorialStep = .wifi
        case .wifi: tutorialStep = .emergencyStop
        case .emergencyStop: tutorialStep = .courseSelection
        case .courseSelection:
            if let selectedTutorialMap {
                startTutorialGame(selectedTutorialMap)
            }
        case .mapLocalization: tutorialStep = .arStart
        case .arStart: tutorialStep = .arControls
        case .arControls: tutorialStep = .gameGoal
        case .gameGoal: closeTutorial()
        case nil: break
        }
    }

    private func goBackInTutorial() {
        switch tutorialStep {
        case .wifi: tutorialStep = .welcome
        case .emergencyStop: tutorialStep = .wifi
        case .courseSelection: tutorialStep = .emergencyStop
        case .mapLocalization: tutorialStep = .courseSelection
        case .arStart: tutorialStep = .mapLocalization
        case .arControls: tutorialStep = .arStart
        case .gameGoal: tutorialStep = .arControls
        case .welcome, nil: break
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
