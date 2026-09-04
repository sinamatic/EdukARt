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

                configureGameController()
            }
            .onDisappear {

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
            arRobotControl
            joystickControl
            timerDisplay
                .allowsHitTesting(false)
            gameplayOverlay
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
                "🪙 \(gameController.collectedCoins)"
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
                            Color(
                                "BrandGreen"
                            )
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
            28
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


    // MARK: - Joystick

    @ViewBuilder
    private var joystickControl: some View {

        if isMapLocalized {

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
                joystickMonitor.xyPoint,
            perform:
                handleJoystickInput
        )
        .onChange(
            of:
                turnJoystickMonitor.xyPoint,
            perform:
                handleTurnJoystickInput
        )
        .onDisappear(
            perform:
                stopJoystickInput
        )
    }


    private func handleJoystickInput(
        _ input: CGPoint
    ) {

        guard isCountdownRunning == false,
              gameController.isRaceFinished == false
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
              gameController.isRaceFinished == false
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

        gameController.setShitEffectHandler { duration in

            controller.startShitEffect(
                duration:
                    duration
            )
        }

        gameController.setOilEffectHandler { duration in

            controller.startOilEffect(
                duration:
                    duration
            )
        }

        gameController.setTreeEffectHandler { duration in

            controller.startTreeEffect(
                duration:
                    duration
            )
        }

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


    private func startCountdown() {

        guard isNoDebugMode,
              isMapLocalized,
              isRobotReadyForRace,
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
        }
    }


    private func updateGameCollision() {

        guard isNoDebugMode,
              hasStartedGameplay,
              gameController.isRaceFinished == false
        else {
            return
        }

        if let realPose =
            controller.realRobotPose {

            updateGameCollision(
                actor:
                    .real,

                with:
                    realPose
            )
        }

        updateGameCollision(
            actor:
                .simulation,

            with:
                controller
                    .eduardSimulation
                    .pose
        )
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

        if gameController.isRaceFinished {

            controller.setGameplayInputLocked(
                true
            )

            disableEduardAfterFinishIfNeeded()
        }
    }


    private func disableEduardAfterFinishIfNeeded() {

        guard didDisableEduardAfterFinish == false
        else {
            return
        }

        didDisableEduardAfterFinish =
            true

        controller.sendDisable()
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
           gameController.isRaceFinished == false {

            Text(
                formattedTime(
                    gameController.elapsedTime
                )
            )
            .font(
                .headline.monospacedDigit()
            )
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
        }
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
                  gameController.isRaceFinished {

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
                    .leading,

                spacing:
                    14
            ) {

                Text(
                    "Finished. Your Time \(formattedTime(gameController.elapsedTime))"
                )
                .font(
                    .title2.bold()
                )
                .foregroundStyle(
                    .white
                )

                scoreSummary

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

                    Text(
                        hasSavedFinishedResult
                        ? "Saved"
                        : "Save Result"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    hasSavedFinishedResult
                )

                leaderboardView
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


    private var scoreSummary: some View {

        VStack(
            alignment:
                .leading,

            spacing:
                6
        ) {

            Text(
                "Points \(gameController.score)"
            )
            Text(
                "Coins \(gameController.collectedCoins) x 100"
            )
            Text(
                "Delivered Eggs \(gameController.deliveredEggs) x 300"
            )
            Text(
                "Oil \(gameController.oilHits) x 0"
            )
            Text(
                "Shit \(gameController.shitHits) x -50"
            )
            Text(
                "Finish 1000"
            )
            Text(
                "Best Time Bonus \(gameController.bestTimeBonusEarned ? 10 : 0)"
            )
        }
        .font(
            .subheadline
        )
        .foregroundStyle(
            .white.opacity(
                0.9
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

            if gameController.leaderboard.isEmpty {

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

                ForEach(
                    gameController.leaderboard.prefix(
                        10
                    )
                ) { result in

                    VStack(
                        alignment:
                            .leading,

                        spacing:
                            3
                    ) {

                        Text(
                            "\(result.playerName) | \(result.trackName)"
                        )
                        .font(
                            .subheadline.bold()
                        )

                        Text(
                            "Time \(formattedTime(result.elapsedTime)) | Coins \(result.collectedCoins) | Eggs \(result.deliveredEggs ?? 0) | Oil \(result.oilHits) | Shit \(result.shitHits) | Points \(result.score)"
                        )
                        .font(
                            .caption
                        )
                    }
                    .foregroundStyle(
                        .white
                    )
                    .padding(
                        8
                    )
                    .frame(
                        maxWidth:
                            .infinity,

                        alignment:
                            .leading
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
