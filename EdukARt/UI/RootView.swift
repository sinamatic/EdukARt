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
    @State private var phase: LaunchPhase = .logo
    @State private var loadingProgress: Double = EdukARtUI.Timing.initialProgress
    @State private var hasStartedLaunchSequence = false
    @State private var selectedGameMap: StoredFloorMap?
    @State private var isGameCameraReady = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch phase {
                case .logo:
                    logoScreen
                case .loading:
                    loadingScreen
                case .menu:
                    menuScreen
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
                    gameMapSelectionScreen
                case .createMap:
                    CreateMapView(
                        mapStore: mapStore,
                        onClose: {
                            phase = .menu
                        },
                        onStartGame: { map in
                            selectedGameMap = map
                            Task {
                                await runGameStartSequence()
                            }
                        }
                    )
                case .viewMaps:
                    MapsView(mapStore: mapStore) {
                        phase = .menu
                    }
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
        phase != .logo
    }

    private var robotStatusOverlayTopPadding: CGFloat {
        switch phase {
        case .remoteControl:
            return EdukARtUI.Layout.robotStatusRemoteTopPadding
        default:
            return EdukARtUI.Layout.robotStatusDefaultTopPadding
        }
    }

    private var logoScreen: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Image("EduArtSinamaticIcon")
                .resizable()
                .scaledToFit()
                .frame(width: EdukARtUI.Layout.logoSize, height: EdukARtUI.Layout.logoSize)
        }
    }

    private var loadingScreen: some View {
        ZStack {
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(EdukARtUI.Opacity.loadingOverlay)
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: EdukARtUI.Layout.loadingPanelSpacing) {
                    Text("Loading \(Int(loadingProgress * Double(EdukARtUI.Timing.progressSteps)))%")
                        .font(.system(size: EdukARtUI.Layout.loadingFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    ProgressView(value: loadingProgress)
                        .tint(.white)
                        .scaleEffect(x: EdukARtUI.Layout.progressScaleX, y: EdukARtUI.Layout.progressScaleY, anchor: .center)
                }
                .padding(.horizontal, EdukARtUI.Layout.loadingPanelHorizontalPadding)
                .padding(.vertical, EdukARtUI.Layout.loadingPanelVerticalPadding)
                .background(.black.opacity(EdukARtUI.Opacity.loadingPanel))
                .clipShape(RoundedRectangle(cornerRadius: EdukARtUI.Layout.loadingPanelCornerRadius, style: .continuous))
                .padding(.horizontal, EdukARtUI.Layout.loadingPanelHorizontalPadding)
                .padding(.bottom, EdukARtUI.Layout.loadingPanelBottomPadding)
            }
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

    private var menuScreen: some View {
        ZStack {
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(EdukARtUI.Opacity.menuOverlay)
                .ignoresSafeArea()

            VStack(spacing: EdukARtUI.Layout.menuOuterSpacing) {
                Spacer()

                VStack(spacing: EdukARtUI.Layout.menuButtonSpacing) {
                    Button("Remote Control Robot") {
                        phase = .remoteControl
                    }
                    .buttonStyle(StartScreenButtonStyle(fillColor: .black.opacity(EdukARtUI.Opacity.primaryMenuButton), foregroundColor: .white))

                    Button("Start Game") {
                        if mapStore.maps.isEmpty {
                            selectedGameMap = nil
                            Task {
                                await runGameStartSequence()
                            }
                        } else {
                            phase = .selectGameMap
                        }
                    }
                    .buttonStyle(StartScreenButtonStyle(fillColor: EdukARtUI.Colors.brandGreen))

                    Button("Create Map") {
                        phase = .createMap
                    }
                    .buttonStyle(StartScreenButtonStyle(fillColor: Color.white.opacity(EdukARtUI.Opacity.lightMenuButton), foregroundColor: EdukARtUI.Colors.brandGreen))

                    Button("View Maps") {
                        phase = .viewMaps
                    }
                    .buttonStyle(StartScreenButtonStyle(fillColor: .black.opacity(EdukARtUI.Opacity.secondaryMenuButton), foregroundColor: .white))
                }
                .padding(.top, EdukARtUI.Layout.menuTopPadding)

                Spacer()
            }
            .padding(.horizontal, EdukARtUI.Layout.menuHorizontalPadding)
            .padding(.vertical, EdukARtUI.Layout.menuVerticalPadding)
        }
    }

    private var gameMapSelectionScreen: some View {
        ZStack {
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(EdukARtUI.Opacity.mapSelectionOverlay)
                .ignoresSafeArea()

            VStack(spacing: EdukARtUI.Layout.mapSelectionSpacing) {
                HStack {
                    Button("Back") {
                        phase = .menu
                    }
                    .buttonStyle(CompactOverlayButtonStyle())

                    Spacer()
                }

                Text("Karte fuer Spiel waehlen")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text("Die Coins werden im Raster auf der gespeicherten Bodenflaeche platziert.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(EdukARtUI.Opacity.secondaryText))

                List {
                    Button {
                        selectedGameMap = nil
                        Task {
                            await runGameStartSequence()
                        }
                    } label: {
                        Text("Ohne Karte starten")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(EdukARtUI.Layout.listItemPadding)
                            .background(Color.white.opacity(EdukARtUI.Opacity.listItemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: EdukARtUI.Layout.listItemCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: EdukARtUI.Layout.listRowVerticalInset, leading: .zero, bottom: EdukARtUI.Layout.listRowVerticalInset, trailing: .zero))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    ForEach(mapStore.maps) { map in
                        Button {
                            selectedGameMap = map
                            Task {
                                await runGameStartSequence()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: EdukARtUI.Layout.listItemContentSpacing) {
                                Text(map.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Text("\(map.floorTiles.count) Bodenkacheln")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(EdukARtUI.Colors.brandGreen)

                                Text("AprilTag \(map.displayReferenceTagNumber)")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(EdukARtUI.Opacity.tertiaryText))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(EdukARtUI.Layout.listItemPadding)
                            .background(Color.white.opacity(EdukARtUI.Opacity.listItemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: EdukARtUI.Layout.listItemCornerRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: EdukARtUI.Layout.listRowVerticalInset, leading: .zero, bottom: EdukARtUI.Layout.listRowVerticalInset, trailing: .zero))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .padding(.horizontal, EdukARtUI.Layout.mapSelectionHorizontalPadding)
            .padding(.top, EdukARtUI.Layout.mapSelectionTopPadding)
            .padding(.bottom, EdukARtUI.Layout.mapSelectionBottomPadding)
        }
    }

    @MainActor
    private func runLaunchSequence() async {
        try? await Task.sleep(for: .seconds(EdukARtUI.Timing.launchLogoDurationSeconds))
        phase = .loading

        let steps = EdukARtUI.Timing.progressSteps
        for step in EdukARtUI.Timing.firstProgressStep...steps {
            loadingProgress = Double(step) / Double(steps)
            try? await Task.sleep(for: .milliseconds(EdukARtUI.Timing.launchProgressStepMilliseconds))
        }

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

private enum LaunchPhase {
    case logo
    case loading
    case menu
    case remoteControl
    case gameLoading
    case game
    case selectGameMap
    case createMap
    case viewMaps
}

private struct StartScreenButtonStyle: ButtonStyle {
    let fillColor: Color
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: EdukARtUI.Layout.startButtonFontSize, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, EdukARtUI.Layout.startButtonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: EdukARtUI.Layout.startButtonCornerRadius, style: .continuous)
                    .fill(fillColor)
                    .opacity(configuration.isPressed ? EdukARtUI.Opacity.pressedButton : EdukARtUI.Layout.defaultButtonScale)
            )
            .foregroundStyle(foregroundColor)
            .scaleEffect(configuration.isPressed ? EdukARtUI.Layout.pressedButtonScale : EdukARtUI.Layout.defaultButtonScale)
            .animation(.easeOut(duration: EdukARtUI.Timing.buttonPressAnimationDuration), value: configuration.isPressed)
    }
}

private struct CompactOverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, EdukARtUI.Layout.compactButtonHorizontalPadding)
            .padding(.vertical, EdukARtUI.Layout.compactButtonVerticalPadding)
            .background(.black.opacity(configuration.isPressed ? EdukARtUI.Opacity.pressedCompactButton : EdukARtUI.Opacity.compactButton))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
