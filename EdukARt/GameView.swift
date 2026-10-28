//
//  GameView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 23.08.26.
// Combined SwiftUI with AR World
//

import SwiftUI
import SwiftUIJoystick
import UIKit
import Combine

struct GameView: View {

    let map:
        GameMap

    @ObservedObject var eduardModelStore:
        EduardModelStore

    @ObservedObject var controller:
        RobotController

    @StateObject private var gameController:
        GameController

    @StateObject private var ghostReplayController =
        ConsumentaGhostReplayController()

    @State private var isMapLocalized =
        false

    @State private var isARMenuOpen =
        false

    @State private var simulationRobotPose =
        RobotPose.zero

    @State private var collisionDebugCounter =
        0

    private let isNoDebugMode =
        true

    @State private var countdownText:
        String?

    @State private var isCountdownRunning =
        false

    @State private var hasStartedGameplay =
        false

    @State private var didPrepareGameStart =
        false

    @State private var playerName =
        ""

    @State private var hasSavedFinishedResult =
        false

    @State private var didDisableEduardAfterFinish =
        false

    @State private var localizationResetID =
        0

    @State private var wasSimulationVisibleBeforeGhost =
        false

    @State private var wasLiveSyncEnabledBeforeGhost =
        false

    @State private var activeGhostRecordingURL:
        URL?

    @State private var isBestGhostEnabled =
        false

    private var isBlockingGhostReplayActive: Bool {
        ghostReplayController.mode == .replay
            && ghostReplayController.phase != .inactive
    }

    private let collisionTimer =
        Timer.publish(
            every:
                0.05,

            on:
                .main,

            in:
                .common
        )
        .autoconnect()
    
    
    // MARK: - Joystick

    @StateObject private var joystickMonitor =
        JoystickMonitor()

    @StateObject private var turnJoystickMonitor =
        JoystickMonitor()
    


    // MARK: - AprilTag Map

    @StateObject private var mapBuilder = AprilTagMapBuilder()

    init(
        map: GameMap,
        eduardModelStore: EduardModelStore,
        controller: RobotController
    ) {

        self.map =
            map

        self.eduardModelStore =
            eduardModelStore

        self.controller =
            controller

        _gameController =
            StateObject(
                wrappedValue:
                    GameController(
                        map:
                            map
                    )
            )
    }

    var body: some View {

        gameContent
            .background(
                SwipeBackDisabler()
            )
            .onReceive(
                collisionTimer
            ) { _ in

                updateGameCollision()
            }
            .onAppear {

                controller.resetGameplayEffects()

                configureGameController()
            }
            .onDisappear {

                if ghostReplayController.phase != .inactive {
                    gameController.endGhostPlayback()
                    controller.eduardSimulation.setPose(
                        .zero
                    )

                    controller.setSimulationVisible(
                        wasSimulationVisibleBeforeGhost
                    )

                    controller.isLiveSyncEnabled =
                        wasLiveSyncEnabledBeforeGhost
                }

                ghostReplayController.reset()

                controller.setGameplayInputLocked(
                    false
                )
            }
    }


    private var gameContent: some View {

        ZStack(
            alignment:
                .topLeading
        ) {

            arView
            savedMapView
                .allowsHitTesting(false)
            preRaceGuidance
            restartIconButton
            arRobotControl
                .opacity(
                    isBlockingGhostReplayActive == false
                    ? 1
                    : 0
                )
                .allowsHitTesting(
                    isBlockingGhostReplayActive == false
                )
            startNewGameButton
            joystickControl
            timerDisplay
                .allowsHitTesting(false)
            gameplayOverlay
            ghostReplayOverlay

        }
    }



    // MARK: - AR View

    private var arView: some View {

        CameraARView(
            eduardModelStore:
                eduardModelStore,

            joystickMonitor:
                joystickMonitor,

            turnJoystickMonitor:
                turnJoystickMonitor,

            mapBuilder:
                mapBuilder,

            controller:
                controller,

            gameController:
                gameController,

            gameMap:
                map,

            localizationResetID:
                localizationResetID,

            requiredReferenceTagID:
                map.referenceTagID,

            onReferenceTagLocalized: {

                withAnimation(
                    .easeInOut(
                        duration:
                            0.45
                    )
                ) {

                    isMapLocalized =
                        true
                }

                if ghostReplayController.phase == .awaitingReference {
                    controller.setSimulationVisible(
                        true
                    )
                }

                ghostReplayController
                    .referenceLocalized()
            },

            onRobotPoseUpdated: { pose in

                controller.updateRealRobotPose(
                    pose
                )
            },

            onRobotPoseLost: {

                controller.eduardOccluder.setEnabled(
                    false
                )
            }
        )
        .ignoresSafeArea()
    }


    // MARK: - Saved Game Map

    private var savedMapView: some View {

        VStack(
            alignment:
                .trailing,

            spacing:
                6
        ) {

            StoredGameMapView(
                map:
                    map,

                robotPose:
                    controller.realRobotPose,

                simulationPose:
                    controller.isSimulationVisible
                    ? simulationRobotPose
                    : nil,

                runtimeMapObjects:
                    gameController.activeMapObjects,

                shitDots:
                    gameController.shitDots
            )
            .frame(
                width:
                    isMapLocalized
                    ? 180
                    : 360,

                height:
                    isMapLocalized
                    ? 180
                    : 360
            )

            Text(
                "🪙 \(gameController.collectedCoins)/\(gameController.totalCoins)"
            )
            .font(
                .caption.bold()
            )
            .foregroundStyle(
                .white
            )
            .padding(
                .horizontal,
                10
            )
            .padding(
                .vertical,
                5
            )
            .background(
                .black.opacity(
                    0.55
                )
            )
            .clipShape(
                Capsule()
            )
        }
        .frame(
            maxWidth:
                .infinity,

            maxHeight:
                .infinity,

            alignment:
                isMapLocalized
                ? .topTrailing
                : .center
        )
        .padding(
            .top,
            isMapLocalized
            ? 20
            : 0
        )
        .padding(
            .trailing,
            isMapLocalized
            ? 20
            : 0
        )
        .animation(
            .easeInOut(
                duration:
                    0.45
            ),
            value:
                isMapLocalized
        )
        .allowsHitTesting(false)
        .task {
            await updateSimulationPoseLoop()
        }
    }


    @MainActor
    private func updateSimulationPoseLoop() async {

        while Task.isCancelled == false {

            simulationRobotPose =
                controller.eduardSimulation.pose

            try? await Task.sleep(
                nanoseconds:
                    50_000_000
            )
        }
    }


    // MARK: - Pre Race Guidance

    @ViewBuilder
    private var preRaceGuidance: some View {

        if isNoDebugMode,
           hasStartedGameplay == false,
           countdownText == nil {

            VStack(
                spacing:
                    12
            ) {

                if isMapLocalized == false {

                    Text(
                        "Localize Map"
                    )
                    .font(
                        .largeTitle.bold()
                    )
                    .foregroundStyle(
                        .white
                    )


                    Text(
                        "Scan and hold the reference AprilTag #\(map.referenceTagID) for 3 seconds. It is marked red in the minimap."
                    )
                    .font(
                        .headline
                    )
                    .multilineTextAlignment(
                        .center
                    )
                    .foregroundStyle(
                        .white.opacity(0.84)
                    )
                    .frame(
                        maxWidth:
                            320
                    )

                } else {

                    Text(
                        "Connect to robot"
                    )
                    .font(
                        .largeTitle.bold()
                    )
                    .foregroundStyle(
                        .white
                    )


                    Text(
                        "Connect to robot (top right corner) and place it on the reference AprilTag. Or insert AR model of robot (top left corner)."
                    )
                    .font(
                        .headline
                    )
                    .multilineTextAlignment(
                        .center
                    )
                    .foregroundStyle(
                        .white.opacity(0.84)
                    )
                    .frame(
                        maxWidth:
                            340
                    )


                    if isRobotReadyForRace {

                        Button {

                            startCountdown()

                        } label: {

                            Text(
                                "I'm Ready"
                            )
                            .font(
                                .headline.bold()
                            )
                            .frame(
                                minWidth:
                                    180
                            )
                        }
                        .buttonStyle(
                            .borderedProminent
                        )
                        .tint(
                            isRobotBehindStartLine
                            ? Color(
                                "BrandGreen"
                            )
                            : .red
                        )
                        .disabled(
                            isRobotBehindStartLine
                                == false
                        )
                        .padding(
                            .top,
                            4
                        )
                    }
                }
            }
            .frame(
                maxWidth:
                    .infinity,

                maxHeight:
                    .infinity,

                alignment:
                    .top
            )
            .padding(
                .top,
                isMapLocalized
                ? 220
                : 70
            )
            .allowsHitTesting(
                isMapLocalized
                && isRobotReadyForRace
            )
        }
    }


    @ViewBuilder
    private var restartIconButton: some View {

        if shouldShowTopRestartButton {

            Button {

                startNewRace()

            } label: {

                HStack(
                    spacing:
                        8
                ) {

                    Image(
                        systemName:
                            "arrow.counterclockwise"
                    )
                    .font(
                        .title3.weight(
                            .bold
                        )
                    )
                    .frame(
                        width:
                            44,

                        height:
                            44
                    )
                    .background(
                        .black.opacity(
                            0.68
                        )
                    )
                    .clipShape(
                        Circle()
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                .white.opacity(
                                    0.36
                                ),
                                lineWidth:
                                    2
                            )
                    }

                    Text(
                        "Restart"
                    )
                    .font(
                        .caption.bold()
                    )
                    .padding(
                        .horizontal,
                        10
                    )
                    .padding(
                        .vertical,
                        7
                    )
                    .background(
                        .black.opacity(
                            0.68
                        )
                    )
                    .clipShape(
                        Capsule()
                    )
                }
                .foregroundStyle(
                    .white
                )
            }
            .buttonStyle(
                .plain
            )
            .frame(
                maxWidth:
                    .infinity,

                maxHeight:
                    .infinity,

                alignment:
                    .topLeading
            )
            .padding(
                .top,
                28
            )
            .padding(
                .leading,
                21
            )
        }
    }


    private var shouldShowTopRestartButton:
        Bool {

        isMapLocalized
        &&
        hasStartedGameplay
        &&
           countdownText == nil
           &&
        gameController.phase == .racing
    }


    // MARK: - AR Robot Control

    private var arRobotControl: some View {

        VStack(
            alignment:
                .leading,
            
            spacing:
                8
        ) {

            Button {

                withAnimation(
                    .easeInOut(
                        duration:
                            0.2
                    )
                ) {

                    isARMenuOpen.toggle()
                }

            } label: {

                Image(
                    systemName:
                        "arkit"
                )
                .font(
                    .title3.weight(
                        .bold
                    )
                )
                .frame(
                    width:
                        44,

                    height:
                        44
                )
                .accessibilityLabel(
                    "AR Menu"
                )
            }
            .buttonStyle(
                RobotStatusIconButtonStyle(
                    isEnabled:
                        isARMenuOpen
                )
            )
            .overlay {
                Circle()
                    .stroke(
                        .white.opacity(
                            0.36
                        ),
                        lineWidth:
                            2
                    )
                    .allowsHitTesting(
                        false
                    )
            }


            if isARMenuOpen {

                VStack(
                    alignment:
                        .leading,

                    spacing:
                        10
                ) {

                    Button {

                        controller
                            .placeSimulationAtReference()

                    } label: {

                        arMenuRow(
                            icon:
                                "scope",

                            title:
                                "Place"
                        )
                    }


                    Button {

                        controller
                            .synchronizeSimulationToEduard()

                    } label: {

                        arMenuRow(
                            icon:
                                "arrow.triangle.2.circlepath",

                            title:
                                "Sync"
                        )
                    }


                    Button {

                        controller.isLiveSyncEnabled.toggle()

                    } label: {

                        arMenuRow(
                            icon:
                                "dot.radiowaves.left.and.right",

                            title:
                                "Live Sync",

                            statusIcon:
                                controller.isLiveSyncEnabled
                                ? "checkmark.circle.fill"
                                : "xmark.circle.fill",

                            statusColor:
                                controller.isLiveSyncEnabled
                                ? .green
                                : .red
                        )
                    }


                    Button {

                        controller
                            .toggleSimulationVisibility()

                    } label: {

                        arMenuRow(
                            icon:
                                controller.isSimulationVisible
                                ? "eye.slash"
                                : "arkit",

                            title:
                                controller.isSimulationVisible
                                ? "Hide AR"
                                : "Show AR"
                        )
                    }

                    Button {
                        isBestGhostEnabled.toggle()
                    } label: {
                        arMenuRow(
                            icon: "car.side.fill",
                            title: "Show Best Ghost",
                            statusIcon: isBestGhostEnabled
                                ? "checkmark.circle.fill"
                                : "xmark.circle.fill",
                            statusColor: isBestGhostEnabled ? .green : .red
                        )
                    }
                    .disabled(gameController.bestGhostRecordingURL == nil)
                }
                .font(
                    .caption.bold()
                )
                .foregroundStyle(
                    .white
                )
                .padding(
                    .horizontal,
                    10
                )
                .padding(
                    .vertical,
                    9
                )
                .background(
                    .black.opacity(
                        0.68
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            8,

                        style:
                            .continuous
                    )
                )
                .transition(
                    .opacity.combined(
                        with:
                            .move(
                                edge:
                                    .top
                            )
                    )
                )
            }
        }
        .buttonStyle(
            .plain
        )
        .padding(
            .top,
            shouldShowTopRestartButton
            ? 84
            : 28
        )
        .padding(
            .leading,
            21
        )
    }


    private func arMenuRow(
        icon: String,
        title: String,
        statusIcon: String? = nil,
        statusColor: Color = .white
    ) -> some View {

        HStack(
            spacing:
                8
        ) {

            ZStack(
                alignment:
                    .topTrailing
            ) {

                Image(
                    systemName:
                        icon
                )
                .frame(
                    width:
                        28,

                    height:
                        22
                )

                if let statusIcon {

                    Image(
                        systemName:
                            statusIcon
                    )
                    .foregroundStyle(
                        statusColor
                    )
                    .font(
                        .caption2
                    )
                    .offset(
                        x:
                            8,

                        y:
                            -4
                    )
                }
            }

            Text(
                title
            )
            .lineLimit(
                1
            )

            Spacer(
                minLength:
                    0
            )
        }
        .frame(
            width:
                124,

            alignment:
                .leading
        )
        .contentShape(
            Rectangle()
        )
    }


    @ViewBuilder
    private var startNewGameButton: some View {

        if isMapLocalized,
           hasStartedGameplay,
           countdownText == nil,
           gameController.phase == .freeDrive,
           isBlockingGhostReplayActive == false {

            Button {

                startNewRace()

            } label: {

                Label(
                    "Start New Game",
                    systemImage:
                        "arrow.counterclockwise"
                )
                .font(
                    .title3.bold()
                )
                .frame(
                    minWidth:
                        260
                )
            }
            .buttonStyle(
                CenterGameButtonStyle()
            )
            .disabled(
                isRobotBehindStartLine
                    == false
            )
            .frame(
                maxWidth:
                    .infinity,

                maxHeight:
                    .infinity,

                alignment:
                    .center
            )
        }
    }


    // MARK: - Joystick

    @ViewBuilder
    private var joystickControl: some View {

        if isMapLocalized,
           isBlockingGhostReplayActive == false {

            VStack {

                Spacer()

                joystickView


                Text(
                    joystickDebugText
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .white
                )
                .frame(
                    maxWidth:
                        .infinity
                )
            }
        }
    }


    private var joystickView: some View {

        JoystickView(
            joystickMonitor:
                joystickMonitor,

            turnJoystickMonitor:
                turnJoystickMonitor,

            width:
                180,

            shape:
                .circle
        )
        .frame(
            maxWidth:
                .infinity
        )
        .onChange(
            of:
                joystickMonitor.xyPoint
        ) { _, newInput in
            handleJoystickInput(newInput)
        }
        .onChange(
            of:
                turnJoystickMonitor.xyPoint
        ) { _, newInput in
            handleTurnJoystickInput(newInput)
        }
        .onDisappear(
            perform:
                stopJoystickInput
        )
    }


    private func handleJoystickInput(
        _ input: CGPoint
    ) {

        guard isCountdownRunning == false,
              gameController.phase != .finished
        else {
            return
        }

        controller.updateJoystickInput(
            x:
                Float(
                    input.x / 180
                ),

            y:
                Float(
                    input.y / 180
                )
        )
    }


    private func handleTurnJoystickInput(
        _ input: CGPoint
    ) {

        guard isCountdownRunning == false,
              gameController.phase != .finished
        else {
            return
        }

        controller.updateMechanumRotationInput(
            x:
                Float(
                    input.x / 120
                )
        )
    }


    private func stopJoystickInput() {

        controller.stopJoystick()

        controller.stopMechanumRotation()
    }


    // MARK: - Game Collision

    private func configureGameController() {

        gameController.setShitEffectHandler { [weak controller] duration in

            controller?.startShitEffect(
                duration:
                    duration
            )
        }

        gameController.setOilEffectHandler { [weak controller] duration in

            controller?.startOilEffect(
                duration:
                    duration
            )
        }

        gameController.setTreeEffectHandler { [weak controller] duration in

            controller?.startTreeEffect(
                duration:
                    duration
            )
        }

        gameController.setWaterModeHandler { [weak controller] active in

            controller?.setWaterMode(
                active
            )
        }

        gameController.setCoinCollectedHandler { [weak controller] in

            controller?.applyCoinSpeedBoost()

            controller?.blinkCoinCollectedLights()
        }

        gameController.setItemboxCollectedHandler { [weak controller] in

            controller?.blinkItemboxCollectedLights()
        }

        gameController.setEggCollectedHandler { [weak controller] in

            controller?.blinkEggCollectedLights()
        }

        gameController.setEggsDeliveredHandler { [weak controller] in

            controller?.repairObstacleDamage()

            controller?.blinkEggsDeliveredLights()
        }

        gameController.setCurrentSpeedPercentProvider { [weak controller] in

            controller?.currentSpeedPercent
            ?? 0
        }

        gameController.setMinSpeedPercentProvider { [weak controller] in

            controller?.minSpeedPercent
            ?? 0
        }

        gameController.setMaxSpeedPercentProvider { [weak controller] in

            controller?.maxSpeedPercent
            ?? 0
        }

        controller.setObstacleDamageHandler { [weak gameController] type in

            gameController?.recordObstacleDamage(
                type:
                    type
            )
        }

        syncBlockingObjects()

        prepareGameStartIfNeeded()
    }


    private func prepareGameStartIfNeeded() {

        guard didPrepareGameStart == false
        else {
            return
        }

        didPrepareGameStart =
            true

        if isNoDebugMode == false {

            hasStartedGameplay =
                true

            controller.setGameplayInputLocked(
                false
            )

            return
        }

        controller.setGameplayInputLocked(
            false
        )
    }


    private var isRobotReadyForRace:
        Bool {

        controller.realRobotPose != nil
            || controller.isSimulationVisible
    }


    private var currentRaceStartPose:
        RobotPose? {

        controller.realRobotPose
        ??
        (
            controller.isSimulationVisible
            ? controller.eduardSimulation.pose
            : nil
        )
    }


    private var isRobotBehindStartLine:
        Bool {

        guard let pose =
            currentRaceStartPose,
              map.trackPoints.count >= 2
        else {
            return false
        }

        let start =
            map.trackPoints[0]

        let next =
            map.trackPoints[1]

        let directionX =
            next.x
            -
            start.x

        let directionZ =
            next.z
            -
            start.z

        let length =
            sqrt(
                directionX * directionX
                +
                directionZ * directionZ
            )

        guard length > 0.001
        else {
            return true
        }

        let robotX =
            pose.position.x
            -
            start.x

        let robotZ =
            pose.position.z
            -
            start.z

        let forwardProjection =
            (
                robotX
                * directionX
                +
                robotZ
                * directionZ
            )
            / length

        return forwardProjection <= 0
    }


    private func startCountdown() {

        guard isNoDebugMode,
              isMapLocalized,
              isRobotReadyForRace,
              isRobotBehindStartLine,
              countdownText == nil,
              hasStartedGameplay == false
        else {
            return
        }

        Task { @MainActor in

            isCountdownRunning =
                true

            controller.setGameplayInputLocked(
                true
            )

            let countdownSteps =
                [
                    "3",
                    "2",
                    "1",
                    "Start"
                ]

            for step in countdownSteps {

                countdownText =
                    step

                try? await Task.sleep(
                    for:
                        .seconds(
                            1
                        )
                )
            }

            countdownText =
                nil

            hasStartedGameplay =
                true

            isCountdownRunning =
                false

            controller.setGameplayInputLocked(
                false
            )

            gameController.startRace()
            startBestLiveGhostIfEnabled()
        }
    }


    private func startNewRace() {

        if controller.isEnabled {

            controller
                .sendDisable()
        }

        controller
            .resetGameplayEffects()

        gameController
            .reset(
                map:
                    map
            )

        syncBlockingObjects()

        hasSavedFinishedResult =
            false

        playerName =
            ""

        didDisableEduardAfterFinish =
            false

        hasStartedGameplay =
            false

        countdownText =
            nil

        isCountdownRunning =
            false

        if isRobotBehindStartLine {

            startCountdown()
        }

        print(
            "# GAME | New race started without relocalization"
        )
    }


    private func closeFinishedOverlay() {

        gameController
            .continueAfterFinish()

        controller.setGameplayInputLocked(
            false
        )
    }


    private func updateGameCollision() {

        guard isNoDebugMode,
              hasStartedGameplay,
              ghostReplayController.phase == .inactive
                || ghostReplayController.mode == .liveRaceGhost
        else {
            return
        }

        if gameController.phase == .finished {
            recordPostFinishPose()
            return
        }

        syncBlockingObjects()

        if let realPose =
            controller.realRobotPose {

            updateGameCollision(
                actor:
                    .real,

                with:
                    realPose
            )
        }

        if controller.isSimulationVisible {
            updateGameCollision(
                actor:
                    .simulation,

                with:
                    controller
                        .eduardSimulation
                        .pose
            )
        }
    }


    private func recordPostFinishPose() {

        switch gameController.finishActor {
        case .real:
            if let realRobotPose = controller.realRobotPose {
                gameController.recordPostFinishRobotPose(
                    realRobotPose,
                    actor: .real
                )
            }

        case .simulation:
            gameController.recordPostFinishRobotPose(
                controller.eduardSimulation.pose,
                actor: .simulation
            )

        case nil:
            break
        }
    }


    private func updateGameCollision(
        actor:
            CollisionActor,

        with gameplayPose:
            RobotPose
    ) {

        printCollisionDebug(
            actor:
                actor,

            gameplayPose:
                gameplayPose
        )

        gameController.updateRobotPose(
            gameplayPose,

            actor:
                actor
        )

        syncBlockingObjects()

        if gameController.phase == .finished {

            controller.setGameplayInputLocked(
                true
            )

            disableEduardAfterFinishIfNeeded()
        }
    }


    private func syncBlockingObjects() {

        controller.updateBlockingObjects(
            gameController.activeMapObjects,

            revealedTreeIDs:
                gameController.revealedTreeIDs
        )
    }


    private func disableEduardAfterFinishIfNeeded() {

        guard didDisableEduardAfterFinish == false
        else {
            return
        }

        didDisableEduardAfterFinish =
            true

        controller.sendDisable()

        controller.startFinishLightEffect()
    }


    private func printCollisionDebug(
        actor:
            CollisionActor,

        gameplayPose:
            RobotPose
    ) {

        collisionDebugCounter += 1

        guard collisionDebugCounter % 20 == 0
        else {
            return
        }


        let realYawText =
            controller.realRobotPose.map {
                String(
                    format:
                        "%.1f",
                    degrees(
                        $0.rotation
                    )
                )
            }
            ?? "nil"

        print(
            String(
                format:
                    "# GAMEPLAY DEBUG | actor %@ | REAL yaw %@ | SIM logical yaw %.1f | MODEL visual yaw %.1f",
                actor.rawValue,
                realYawText,
                degrees(
                    controller.eduardSimulation.pose.rotation
                )
            )
        )
    }


    private func degrees(
        _ radians:
            Float
    ) -> Float {

        radians * 180 / .pi
    }


    private var joystickDebugText:
        String {

        String(
            format:
                "Forward: %.2f   Sideways: %.2f   Turn: %.2f",
            joystickMonitor.xyPoint.y,
            joystickMonitor.xyPoint.x,
            turnJoystickMonitor.xyPoint.x
        )
    }


    // MARK: - Gameplay UI

    @ViewBuilder
    private var timerDisplay: some View {

        if isNoDebugMode,
           hasStartedGameplay,
           gameController.phase == .racing {

            HStack(
                spacing:
                    8
            ) {

                Text(
                    formattedTime(
                        gameController.elapsedTime
                    )
                )
                .font(
                    .headline.monospacedDigit()
                )

                Text(
                    "Speed \(controller.currentSpeedPercent)%"
                )
                .font(
                    .caption.bold()
                )

                Text(
                    "Damage \(gameController.obstacleHits)"
                )
                .font(
                    .caption.bold()
                )
            }
            .foregroundStyle(
                .white
            )
            .padding(
                .horizontal,
                14
            )
            .padding(
                .vertical,
                8
            )
            .background(
                .black.opacity(
                    0.62
                )
            )
            .clipShape(
                Capsule()
            )
            .frame(
                maxWidth:
                    .infinity,

                maxHeight:
                    .infinity,

                alignment:
                    .top
            )
            .padding(
                .top,
                28
            )
            .offset(
                y:
                    -50
            )
        }
    }


    @ViewBuilder
    private var ghostReplayOverlay: some View {
        if ghostReplayController.mode == .replay {
            ConsumentaGhostReplayView(
            phase:
                ghostReplayController.phase,

            referenceTagID:
                map.referenceTagID,

            onStart: {
                startGhostReplay()
            },

            onReplay: {
                if let recordingURL = activeGhostRecordingURL {

                    prepareGhostReplay(
                        recordingURL:
                            recordingURL
                    )
                }
            },

            onClose: {
                finishGhostReplay()
            }
            )
        }
    }

    private func startBestLiveGhostIfEnabled() {
        guard isBestGhostEnabled,
              let url = gameController.bestGhostRecordingURL else {
            return
        }

        ghostReplayController.prepare(
            recordingURL: url,
            mode: .liveRaceGhost,
            simulation: controller.eduardSimulation
        )
        guard ghostReplayController.phase != .failed else {
            return
        }

        ghostReplayController.referenceLocalized()
        controller.setSimulationVisible(true)
        ghostReplayController.start(
            simulation: controller.eduardSimulation,
            onEvent: { _ in },
            onFinished: {}
        )
    }


    private func prepareGhostReplay(
        recordingURL: URL,
        mode: GhostPlaybackMode = .replay
    ) {

        let isStartingNewGhostSession =
            ghostReplayController.phase == .inactive

        ghostReplayController.prepare(
            recordingURL:
                recordingURL,

            mode:
                mode,

            simulation:
                controller.eduardSimulation
        )

        guard ghostReplayController.phase != .failed
        else {
            return
        }

        activeGhostRecordingURL = recordingURL

        stopJoystickInput()

        controller.sendDisable()
        controller.setGameplayInputLocked(
            true
        )

        if isStartingNewGhostSession {
            wasSimulationVisibleBeforeGhost =
                controller.isSimulationVisible

            wasLiveSyncEnabledBeforeGhost =
                controller.isLiveSyncEnabled
        }

        controller.isLiveSyncEnabled =
            false

        controller.setSimulationVisible(
            false
        )

        isMapLocalized =
            false

        localizationResetID +=
            1
    }


    private func startGhostReplay() {

        controller.setGameplayInputLocked(
            true
        )

        if let recording = ghostReplayController.recording {
            gameController.beginGhostPlayback(
                recording: recording,
                mode: ghostReplayController.mode
            )
        }

        ghostReplayController.start(
            simulation: controller.eduardSimulation,
            onEvent: { event in
                gameController.applyGhostEvent(event)
            },
            onFinished: {
                gameController.endGhostPlayback()
            }
        )
    }


    private func finishGhostReplay() {

        gameController.endGhostPlayback()
        ghostReplayController.reset()
        activeGhostRecordingURL = nil

        controller.eduardSimulation.setPose(
            .zero
        )

        controller.setSimulationVisible(
            wasSimulationVisibleBeforeGhost
        )

        controller.isLiveSyncEnabled =
            wasLiveSyncEnabledBeforeGhost

        controller.setGameplayInputLocked(
            false
        )
    }


    @ViewBuilder
    private var gameplayOverlay: some View {

        if let countdownText {

            outlinedCountdownText(
                countdownText
            )
            .frame(
                maxWidth:
                    .infinity,

                maxHeight:
                    .infinity
            )
            .allowsHitTesting(
                false
            )

        } else if isNoDebugMode,
                  gameController.phase == .finished,
                  isBlockingGhostReplayActive == false {

            finishView
        }
    }


    private func outlinedCountdownText(
        _ text:
            String
    ) -> some View {

        Text(
            text
        )
        .font(
            .system(
                size:
                    168,

                weight:
                    .bold,

                design:
                    .rounded
            )
        )
        .foregroundStyle(
            .white
        )
        .shadow(
            color:
                .black,

            radius:
                0,

            x:
                4,

            y:
                0
        )
        .shadow(
            color:
                .black,

            radius:
                0,

            x:
                -4,

            y:
                0
        )
        .shadow(
            color:
                .black,

            radius:
                0,

            x:
                0,

            y:
                4
        )
        .shadow(
            color:
                .black,

            radius:
                0,

            x:
                0,

            y:
                -4
        )
        .shadow(
            radius:
                8
        )
    }


    private var finishView: some View {

        ScrollView {

            VStack(
                alignment:
                    .center,

                spacing:
                    16
            ) {

                HStack {

                    Spacer()

                    Button {

                        closeFinishedOverlay()

                    } label: {

                        Image(
                            systemName:
                                "xmark"
                        )
                        .font(
                            .headline.bold()
                        )
                        .frame(
                            width:
                                34,

                            height:
                                34
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                    .foregroundStyle(
                        .white
                    )
                    .background(
                        .white.opacity(
                            0.12
                        )
                    )
                    .clipShape(
                        Circle()
                    )
                }

                Text(
                    "Finished"
                )
                .font(
                    .largeTitle.bold()
                )
                .foregroundStyle(
                    .white
                )

                Text(
                    "Your Time"
                )
                .font(
                    .headline
                )
                .foregroundStyle(
                    .white.opacity(
                        0.76
                    )
                )

                Text(
                    formattedTime(
                        gameController.elapsedTime
                    )
                )
                .font(
                    .system(
                        size:
                            52,

                        weight:
                            .bold,

                        design:
                            .rounded
                    )
                    .monospacedDigit()
                )
                .foregroundStyle(
                    Color(
                        "BrandGreen"
                    )
                )
                .frame(
                    maxWidth:
                        .infinity
                )

                resultSummary

                resultingTimeSummary

                TextField(
                    "Name",
                    text:
                        $playerName
                )
                .textFieldStyle(
                    .roundedBorder
                )
                .disabled(
                    hasSavedFinishedResult
                )

                Button {

                    gameController.saveFinishedResult(
                        playerName:
                            playerName
                    )

                    hasSavedFinishedResult =
                        true

                } label: {

                    Label(
                        hasSavedFinishedResult
                            ? "Saved"
                            : "Save Result",
                        systemImage:
                            hasSavedFinishedResult
                            ? "checkmark"
                            : "square.and.arrow.down"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    ResultSaveButtonStyle()
                )
                .disabled(
                    hasSavedFinishedResult
                )

                leaderboardView

                if let recordingURL =
                    gameController.latestDriveRecordingURL {

                    ConsumentaDriveSharingView(
                        recordingURL:
                            recordingURL
                    )

                    Button {
                        prepareGhostReplay(
                            recordingURL:
                                recordingURL
                        )
                    } label: {
                        Label(
                            "Show Ghost Race Again",
                            systemImage:
                                "car.side"
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                    .buttonStyle(
                        ResultSaveButtonStyle()
                    )
                }
            }
            .padding(
                18
            )
            .background(
                .black.opacity(
                    0.82
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        8,

                    style:
                        .continuous
                )
            )
            .padding(
                24
            )
        }
        .frame(
            maxWidth:
                .infinity,

            maxHeight:
                .infinity
        )
        .background(
            .black.opacity(
                0.35
            )
        )
    }


    private var resultSummary: some View {

        ItemStatsTableView(
            stats:
                [
                    ItemStat(
                        emoji:
                            "🪙",
                        title:
                            "Coins",
                        value:
                            "\(gameController.collectedCoins)/\(gameController.totalCoins)"
                    ),
                    ItemStat(
                        emoji:
                            "🎁",
                        title:
                            "Itemboxes",
                        value:
                            "\(gameController.collectedItemboxes)"
                    ),
                    ItemStat(
                        emoji:
                            "🥚",
                        title:
                            "Collected Eggs",
                        value:
                            "\(gameController.collectedEggs)"
                    ),
                    ItemStat(
                        emoji:
                            "🪺",
                        title:
                            "Delivered Eggs",
                        value:
                            "\(gameController.deliveredEggs)"
                    ),
                    ItemStat(
                        emoji:
                            "🛢",
                        title:
                            "Slipped on Oil",
                        value:
                            "\(gameController.oilHits)"
                    ),
                    ItemStat(
                        emoji:
                            "💩",
                        title:
                            "Road Pollution",
                        value:
                            "\(gameController.shitHits)"
                    ),
                    ItemStat(
                        emoji:
                            "🪨",
                        title:
                            "Crashed with Rock",
                        value:
                            "\(gameController.rockHits)"
                    ),
                    ItemStat(
                        emoji:
                            "🌳",
                        title:
                            "Crashed with Tree",
                        value:
                            "\(gameController.treeHits)"
                    ),
                    ItemStat(
                        emoji:
                            "⚡",
                        title:
                            "Final Speed",
                        value:
                            "\(controller.currentSpeedPercent)%"
                    ),
                    ItemStat(
                        emoji:
                            "⬇️",
                        title:
                            "Min Speed",
                        value:
                            "\(controller.minSpeedPercent)%"
                    ),
                    ItemStat(
                        emoji:
                            "⬆️",
                        title:
                            "Max Speed",
                        value:
                            "\(controller.maxSpeedPercent)%"
                    )
                ]
        )
    }


    private var resultingTimeSummary: some View {

        VStack(
            spacing:
                6
        ) {

            Text(
                "Resulting Time"
            )
            .font(
                .caption.bold()
            )
            .foregroundStyle(
                .white.opacity(
                    0.68
                )
            )

            Text(
                formattedTime(
                    gameController.resultingTime
                )
            )
            .font(
                .system(
                    size:
                        32,

                    weight:
                        .bold,

                    design:
                        .rounded
                )
                .monospacedDigit()
            )
            .foregroundStyle(
                Color(
                    "BrandGreen"
                )
            )

            Text(
                "\(gameController.missingCoins) missing coins x 5s = +\(formattedTime(gameController.coinTimePenalty))"
            )
            .font(
                .caption2.bold()
            )
            .foregroundStyle(
                .white.opacity(
                    0.62
                )
            )

            Text(
                "\(gameController.collectedItemboxes) itemboxes x 20s = -\(formattedTime(gameController.itemboxTimeBonus))"
            )
            .font(
                .caption2.bold()
            )
            .foregroundStyle(
                .white.opacity(
                    0.62
                )
            )
        }
        .frame(
            maxWidth:
                .infinity
        )
        .padding(
            10
        )
        .background(
            .white.opacity(
                0.08
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    8,

                style:
                    .continuous
            )
        )
    }


    private var leaderboardView: some View {

        VStack(
            alignment:
                .leading,

            spacing:
                8
        ) {

            Text(
                "Leaderboard"
            )
            .font(
                .headline
            )
            .foregroundStyle(
                .white
            )

            LeaderboardResultsView(
                results:
                    Array(
                        gameController.leaderboard.prefix(
                            10
                        )
                    ),
                onGhostSelected: { result in
                    guard let url = gameController.ghostRecordingURL(for: result) else {
                        return
                    }
                    prepareGhostReplay(recordingURL: url, mode: .replay)
                },
                ghostURLProvider: { result in
                    gameController.ghostRecordingURL(for: result)
                },
                onDelete: { result in
                    gameController.deleteLeaderboardResult(result)
                }
            )
        }
    }


    private func formattedTime(
        _ time:
            TimeInterval
    ) -> String {

        String(
            format:
                "%.2f s",
            time
        )
    }


}


struct ItemStat:
    Identifiable {

    let id =
        UUID()

    let emoji:
        String

    let title:
        String

    let value:
        String
}


struct ItemStatsTableView: View {

    let stats:
        [ItemStat]

    private let columns =
        [
            GridItem(
                .flexible(),
                spacing:
                    8
            ),
            GridItem(
                .flexible(),
                spacing:
                    8
            )
        ]


    var body: some View {

        LazyVGrid(
            columns:
                columns,

            alignment:
                .leading,

            spacing:
                8
        ) {

            ForEach(
                stats
            ) { stat in

                HStack(
                    spacing:
                        8
                ) {

                    Text(
                        stat.emoji
                    )
                    .font(
                        .title3
                    )
                    .frame(
                        width:
                            28
                    )

                    VStack(
                        alignment:
                            .leading,

                        spacing:
                            1
                    ) {

                        Text(
                            stat.title
                        )
                        .font(
                            .caption2.bold()
                        )
                        .foregroundStyle(
                            .white.opacity(
                                0.66
                            )
                        )

                        Text(
                            stat.value
                        )
                        .font(
                            .subheadline.bold()
                        )
                        .foregroundStyle(
                            .white
                        )
                    }

                    Spacer(
                        minLength:
                            0
                    )
                }
                .padding(
                    8
                )
                .background(
                    .white.opacity(
                        0.08
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            8,

                        style:
                            .continuous
                    )
                )
            }
        }
    }
}


struct LeaderboardTableView: View {

    let results:
        [GameResult]

    let onGhostSelected: (GameResult) -> Void
    let ghostURLProvider: (GameResult) -> URL?
    let onDelete: ((GameResult) -> Void)?

    init(
        results: [GameResult],
        onGhostSelected: @escaping (GameResult) -> Void = { _ in },
        ghostURLProvider: @escaping (GameResult) -> URL? = { _ in nil },
        onDelete: ((GameResult) -> Void)? = nil
    ) {
        self.results = results
        self.onGhostSelected = onGhostSelected
        self.ghostURLProvider = ghostURLProvider
        self.onDelete = onDelete
    }

    @State private var selectedResultID:
        UUID?

    private let rankColumnWidth:
        CGFloat = 36

    private let nameColumnWidth:
        CGFloat = 118

    private let valueColumnWidth:
        CGFloat = 54


    var body: some View {
        let displayedResults = Array(results.prefix(10).enumerated())

        List {
            ScrollView(.horizontal, showsIndicators: false) {
                leaderboardHeader
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 4, trailing: 8))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(displayedResults, id: \.element.id) { index, result in
                let isSelected = selectedResultID == result.id

                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        leaderboardRow(rank: index + 1, result: result)
                            .frame(minHeight: 58)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedResultID = isSelected ? nil : result.id
                        }
                    }

                    if isSelected {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Ghost Drive: \(result.playerName)")
                                .font(.headline)
                                .foregroundStyle(.white)

                            if result.ghostID != nil,
                               ghostURLProvider(result) != nil {
                                Button {
                                    onGhostSelected(result)
                                } label: {
                                    Label(
                                        "Start AR Ghost Drive on Course \(result.trackName)",
                                        systemImage: "arkit"
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("BrandGreen"))

                                if let ghostURL = ghostURLProvider(result) {
                                    ShareLink(item: ghostURL) {
                                        Label(
                                            "Share Ghost Drive",
                                            systemImage: "square.and.arrow.up"
                                        )
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.white)
                                }
                            } else {
                                Text("No Ghost Drive is available for this result.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Color("BrandGreen").opacity(
                        isSelected ? 0.18 : (index.isMultiple(of: 2) ? 0.055 : 0.095)
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if let onDelete {
                        Button("Delete", role: .destructive) {
                            onDelete(result)
                            if selectedResultID == result.id {
                                selectedResultID = nil
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .frame(
            height: CGFloat(displayedResults.count * 82 + 48)
                + (selectedResultID == nil ? 0 : 154)
        )
        .background(Color.clear)
    }

    private var leaderboardHeader: some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: rankColumnWidth)
            Text("Name")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.68))
                .frame(width: nameColumnWidth, alignment: .leading)

            ForEach(leaderboardColumns) { column in
                Text(column.emoji)
                    .font(.title3)
                    .frame(width: valueColumnWidth, height: 28)
            }
        }
    }

    private func leaderboardRow(rank: Int, result: GameResult) -> some View {
        HStack(spacing: 6) {
            Text("#\(rank)")
                .font(.caption.bold())
                .foregroundStyle(Color("BrandGreen"))
                .frame(width: rankColumnWidth)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.playerName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let ghostID = result.ghostID {
                    Label(
                        "Ghost \(ghostID.uuidString.prefix(6))",
                        systemImage: "car.side.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(Color("BrandGreen"))
                    .lineLimit(1)
                }
            }
            .frame(width: nameColumnWidth, alignment: .leading)

            ForEach(leaderboardValues(for: result)) { stat in
                Text(stat.value)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: valueColumnWidth)
            }
        }
    }


    private var leaderboardColumns:
        [ItemStat] {

        [
            ItemStat(
                emoji:
                    "🏁",
                title:
                    "Resulting Time",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "⏱",
                title:
                    "Time",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "🪙",
                title:
                    "Coins",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "🎁",
                title:
                    "Itemboxes",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "🥚",
                title:
                    "Collected Eggs",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "🪺",
                title:
                    "Delivered Eggs",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "🛢",
                title:
                    "Slipped on Oil",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "💩",
                title:
                    "Road Pollution",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "🪨",
                title:
                    "Crashed with Rock",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "🌳",
                title:
                    "Crashed with Tree",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "⚡",
                title:
                    "Final Speed",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "⬇️",
                title:
                    "Min Speed",
                value:
                    ""
            ),
            ItemStat(
                emoji:
                    "⬆️",
                title:
                    "Max Speed",
                value:
                    ""
            )
        ]
    }


    private func leaderboardValues(
        for result:
            GameResult
    ) -> [ItemStat] {

        [
            ItemStat(
                emoji:
                    "🏁",
                title:
                    "Resulting Time",
                value:
                    formattedTime(
                        rankingTime(
                            for:
                                result
                        )
                    )
            ),
            ItemStat(
                emoji:
                    "⏱",
                title:
                    "Time",
                value:
                    formattedTime(
                        result.elapsedTime
                    )
            ),
            ItemStat(
                emoji:
                    "🪙",
                title:
                    "Coins",
                value:
                    coinText(
                        for:
                            result
                    )
            ),
            ItemStat(
                emoji:
                    "🎁",
                title:
                    "Itemboxes",
                value:
                    "\(result.collectedItemboxes ?? 0)"
            ),
            ItemStat(
                emoji:
                    "🥚",
                title:
                    "Collected Eggs",
                value:
                    "\(result.collectedEggs ?? 0)"
            ),
            ItemStat(
                emoji:
                    "🪺",
                title:
                    "Delivered Eggs",
                value:
                    "\(result.deliveredEggs ?? 0)"
            ),
            ItemStat(
                emoji:
                    "🛢",
                title:
                    "Slipped on Oil",
                value:
                    "\(result.oilHits)"
            ),
            ItemStat(
                emoji:
                    "💩",
                title:
                    "Road Pollution",
                value:
                    "\(result.shitHits)"
            ),
            ItemStat(
                emoji:
                    "🪨",
                title:
                    "Crashed with Rock",
                value:
                    "\(result.rockHits ?? 0)"
            ),
            ItemStat(
                emoji:
                    "🌳",
                title:
                    "Crashed with Tree",
                value:
                    "\(result.treeHits ?? 0)"
            ),
            ItemStat(
                emoji:
                    "⚡",
                title:
                    "Final Speed",
                value:
                    speedText(
                        for:
                            result
                    )
            ),
            ItemStat(
                emoji:
                    "⬇️",
                title:
                    "Min Speed",
                value:
                    speedText(
                        result.minSpeedPercent
                    )
            ),
            ItemStat(
                emoji:
                    "⬆️",
                title:
                    "Max Speed",
                value:
                    speedText(
                        result.maxSpeedPercent
                    )
            )
        ]
    }


    private func formattedTime(
        _ time:
            TimeInterval
    ) -> String {

        String(
            format:
                "%.2f",
            time
        )
    }


    private func speedText(
        for result:
            GameResult
    ) -> String {

        speedText(
            result.finalSpeedPercent
        )
    }


    private func speedText(
        _ speedPercent:
            Int?
    ) -> String {

        guard let speedPercent
        else {
            return "-"
        }

        return "\(speedPercent)%"
    }


    private func rankingTime(
        for result:
            GameResult
    ) -> TimeInterval {

        result.resultingTime
        ??
        result.elapsedTime
    }


    private func coinText(
        for result:
            GameResult
    ) -> String {

        guard let totalCoins =
            result.totalCoins
        else {
            return "\(result.collectedCoins)"
        }

        return "\(result.collectedCoins)/\(totalCoins)"
    }
}


struct LeaderboardResultsView: View {

    let results:
        [GameResult]

    let onGhostSelected: (GameResult) -> Void
    let ghostURLProvider: (GameResult) -> URL?
    let onDelete: ((GameResult) -> Void)?

    init(
        results: [GameResult],
        onGhostSelected: @escaping (GameResult) -> Void = { _ in },
        ghostURLProvider: @escaping (GameResult) -> URL? = { _ in nil },
        onDelete: ((GameResult) -> Void)? = nil
    ) {
        self.results = results
        self.onGhostSelected = onGhostSelected
        self.ghostURLProvider = ghostURLProvider
        self.onDelete = onDelete
    }


    var body: some View {

        if results.isEmpty {

            Text(
                "No saved results yet"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .white.opacity(
                    0.7
                )
            )

        } else {

            LeaderboardTableView(
                results:
                    results,
                onGhostSelected:
                    onGhostSelected,
                ghostURLProvider:
                    ghostURLProvider,
                onDelete:
                    onDelete
            )
        }
    }
}


private struct CenterGameButtonStyle: ButtonStyle {

    @Environment(\.isEnabled)
    private var isEnabled


    func makeBody(
        configuration:
            Configuration
    ) -> some View {

        configuration.label
            .frame(
                maxWidth:
                    .infinity
            )
            .foregroundStyle(
                .white
            )
            .padding(
                .horizontal,
                24
            )
            .padding(
                .vertical,
                16
            )
            .background(
                Color(
                    "BrandGreen"
                )
                .opacity(
                    isEnabled == false
                    ? 0.24
                    : configuration.isPressed
                    ? 0.54
                    : 0.70
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        18,

                    style:
                        .continuous
                )
            )
            .scaleEffect(
                configuration.isPressed
                ? 0.95
                : 1
            )
            .animation(
                .easeOut(
                    duration:
                        0.12
                ),
                value:
                    configuration.isPressed
            )
    }
}


private struct ResultSaveButtonStyle: ButtonStyle {

    func makeBody(
        configuration:
            Configuration
    ) -> some View {

        configuration.label
            .font(
                .headline.bold()
            )
            .foregroundStyle(
                .white
            )
            .padding()
            .background(
                Color(
                    "BrandGreen"
                )
                .opacity(
                    configuration.isPressed
                    ? 0.72
                    : 1.0
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        18,

                    style:
                        .continuous
                )
            )
            .scaleEffect(
                configuration.isPressed
                ? 0.97
                : 1
            )
            .animation(
                .easeOut(
                    duration:
                        0.12
                ),
                value:
                    configuration.isPressed
            )
    }
}


struct SwipeBackDisabler:
    UIViewControllerRepresentable {

    func makeUIViewController(
        context: Context
    ) -> UIViewController {

        UIViewController()
    }


    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {

        DispatchQueue.main.async {

            uiViewController
                .navigationController?
                .interactivePopGestureRecognizer?
                .isEnabled =
                false
        }
    }


    static func dismantleUIViewController(
        _ uiViewController: UIViewController,
        coordinator: ()
    ) {

        uiViewController
            .navigationController?
            .interactivePopGestureRecognizer?
            .isEnabled =
            true
    }
}
