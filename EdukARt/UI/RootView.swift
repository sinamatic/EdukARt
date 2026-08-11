//
//  RootView.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import SwiftUI

enum EdukARtUI {
    enum Colors {
        static let brandGreen = Color(red: 12.0 / 255.0, green: 117.0 / 255.0, blue: 0)
    }

    enum Opacity {
        static let loadingOverlay = 0.22
        static let loadingPanel = 0.55
        static let gameLoadingPanel = 0.42
        static let menuOverlay = 0.66
        static let mapSelectionOverlay = 0.84
        static let primaryMenuButton = 0.62
        static let secondaryMenuButton = 0.42
        static let lightMenuButton = 0.82
        static let listItemBackground = 0.1
        static let secondaryText = 0.82
        static let tertiaryText = 0.78
        static let pressedButton = 0.82
        static let compactButton = 0.65
        static let pressedCompactButton = 0.48
    }

    enum Layout {
        static let robotStatusTrailingPadding: CGFloat = 24
        static let robotStatusRemoteTopPadding: CGFloat = 15
        static let robotStatusDefaultTopPadding: CGFloat = 56
        static let logoSize: CGFloat = 220
        static let loadingPanelSpacing: CGFloat = 14
        static let loadingPanelHorizontalPadding: CGFloat = 28
        static let loadingPanelVerticalPadding: CGFloat = 22
        static let loadingPanelCornerRadius: CGFloat = 22
        static let loadingPanelBottomPadding: CGFloat = 56
        static let loadingFontSize: CGFloat = 20
        static let progressScaleX: CGFloat = 1
        static let progressScaleY: CGFloat = 1.5
        static let menuOuterSpacing: CGFloat = 24
        static let menuButtonSpacing: CGFloat = 14
        static let menuTopPadding: CGFloat = 8
        static let menuHorizontalPadding: CGFloat = 28
        static let menuVerticalPadding: CGFloat = 40
        static let mapSelectionSpacing: CGFloat = 20
        static let mapSelectionHorizontalPadding: CGFloat = 24
        static let mapSelectionTopPadding: CGFloat = 34
        static let mapSelectionBottomPadding: CGFloat = 24
        static let listItemPadding: CGFloat = 18
        static let listItemContentSpacing: CGFloat = 8
        static let listItemCornerRadius: CGFloat = 18
        static let listRowVerticalInset: CGFloat = 6
        static let startButtonFontSize: CGFloat = 20
        static let startButtonVerticalPadding: CGFloat = 18
        static let startButtonCornerRadius: CGFloat = 18
        static let pressedButtonScale: CGFloat = 0.98
        static let defaultButtonScale: CGFloat = 1
        static let compactButtonHorizontalPadding: CGFloat = 16
        static let compactButtonVerticalPadding: CGFloat = 12
    }

    enum Timing {
        static let launchLogoDurationSeconds: TimeInterval = 3
        static let cameraReadyFallbackDelaySeconds: TimeInterval = 1
        static let progressSteps = 100
        static let launchProgressStepMilliseconds: UInt64 = 30
        static let gameProgressStepMilliseconds: UInt64 = 42
        static let buttonPressAnimationDuration = 0.12
        static let initialProgress = 0.0
        static let firstProgressStep = 0
    }
}

struct RootView: View {
    @StateObject private var mapStore = MapStore()
    @StateObject private var robotRemoteController = EduardRemoteControlController()
    @State private var phase: AppPhase = .logo
    @State private var loadingProgress: Double = EdukARtUI.Timing.initialProgress
    @State private var hasStartedLaunchSequence = false
    @State private var selectedGameMap: StoredFloorMap?
    @State private var isGameCameraReady = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch phase {
                case .logo:
                    UILogo()
                case .menu:
                    UIMenuMain(
                        onStartGame: {
                            phase = .selectGameMap
                        },
                        onRobotControl: {
                            phase = .remoteControl
                        }
                    )
                case .remoteControl:
                    RobotRemoteControlScreen(controller: robotRemoteController) {
                        phase = .menu
                    }
                case .gameLoading:
                    gameLoadingScreen
                case .game:
                    ZStack {
                        GameView(
                            selectedMap: selectedGameMap,
                            onCameraReady: {
                                isGameCameraReady = true
                            }
                        ) {
                            isGameCameraReady = false
                            phase = .menu
                        }

                        if isGameCameraReady == false {
                            gameLoadingScreen
                        }
                    }
                case .selectGameMap:
                    UIStartGameChooseMap(
                        mapStore: mapStore,
                        onBack: {
                            phase = .menu
                        },
                        onCreateMap: {
                            phase = .createGameMap
                        },
                        onStartGame: { map in
                            selectedGameMap = map
                            Task {
                                await runGameStartSequence()
                            }
                        }
                    )
                case .createGameMap:
                    CreateMapView(
                        mapStore: mapStore,
                        onClose: {
                            phase = .selectGameMap
                        },
                        onStartGame: { map in
                            selectedGameMap = map
                            Task {
                                await runGameStartSequence()
                            }
                        }
                    )
                }
            }

            if showsRobotStatusOverlay {
                UIRobotStatusOverlay(controller: robotRemoteController)
                    .padding(.top, robotStatusOverlayTopPadding)
                    .padding(.trailing, EdukARtUI.Layout.robotStatusTrailingPadding)
            }
        }
        .task {
            guard hasStartedLaunchSequence == false else {
                return
            }

            hasStartedLaunchSequence = true
            await runLaunchSequence()
        }
    }

    private var showsRobotStatusOverlay: Bool {
        switch phase {
        case .logo, .selectGameMap, .createGameMap:
            return false
        case .menu, .remoteControl, .gameLoading, .game:
            return true
        }
    }

    private var robotStatusOverlayTopPadding: CGFloat {
        switch phase {
        case .remoteControl:
            return EdukARtUI.Layout.robotStatusRemoteTopPadding
        default:
            return EdukARtUI.Layout.robotStatusDefaultTopPadding
        }
    }

    private var gameLoadingScreen: some View {
        ZStack {
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: EdukARtUI.Layout.loadingPanelSpacing) {
                    Text("Starting Game \(Int(loadingProgress * Double(EdukARtUI.Timing.progressSteps)))%")
                        .font(.system(size: EdukARtUI.Layout.loadingFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    ProgressView(value: loadingProgress)
                        .tint(EdukARtUI.Colors.brandGreen)
                        .scaleEffect(x: EdukARtUI.Layout.progressScaleX, y: EdukARtUI.Layout.progressScaleY, anchor: .center)
                }
                .padding(.horizontal, EdukARtUI.Layout.loadingPanelHorizontalPadding)
                .padding(.vertical, EdukARtUI.Layout.loadingPanelVerticalPadding)
                .background(.black.opacity(EdukARtUI.Opacity.gameLoadingPanel))
                .clipShape(RoundedRectangle(cornerRadius: EdukARtUI.Layout.loadingPanelCornerRadius, style: .continuous))
                .padding(.horizontal, EdukARtUI.Layout.loadingPanelHorizontalPadding)
                .padding(.bottom, EdukARtUI.Layout.loadingPanelBottomPadding)
            }
        }
    }

    @MainActor
    private func runLaunchSequence() async {
        try? await Task.sleep(for: .seconds(EdukARtUI.Timing.launchLogoDurationSeconds))
        phase = .menu
    }

    @MainActor
    private func runGameStartSequence() async {
        loadingProgress = EdukARtUI.Timing.initialProgress
        isGameCameraReady = false
        phase = .gameLoading

        let steps = EdukARtUI.Timing.progressSteps
        for step in EdukARtUI.Timing.firstProgressStep...steps {
            loadingProgress = Double(step) / Double(steps)
            try? await Task.sleep(for: .milliseconds(EdukARtUI.Timing.gameProgressStepMilliseconds))
        }

        phase = .game
        try? await Task.sleep(for: .seconds(EdukARtUI.Timing.cameraReadyFallbackDelaySeconds))
        if isGameCameraReady == false {
            isGameCameraReady = true
        }
    }
}

private enum AppPhase {
    case logo
    case menu
    case remoteControl
    case gameLoading
    case game
    case selectGameMap
    case createGameMap
}
