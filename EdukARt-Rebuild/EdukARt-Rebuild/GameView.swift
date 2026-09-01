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
    }


    private var gameContent: some View {

        ZStack(
            alignment:
                .topLeading
        ) {

            arView
            savedMapView
                .allowsHitTesting(false)
            localizationHeading
                .allowsHitTesting(false)
            arRobotControl
            joystickControl
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
            }
        )
        .ignoresSafeArea()
    }


    // MARK: - Saved Game Map

    private var savedMapView: some View {

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

            shitTrailPoints:
                gameController.shitTrailPoints
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


    // MARK: - Localization Heading

    @ViewBuilder
    private var localizationHeading: some View {

        if isMapLocalized == false {

            VStack(
                spacing:
                    8
            ) {

                Text(
                    "Localize Course"
                )
                .font(
                    .largeTitle.bold()
                )
                .foregroundStyle(
                    .white
                )


                Text(
                    "Scan AprilTag #\(map.referenceTagID)"
                )
                .font(
                    .headline
                )
                .foregroundStyle(
                    .white.opacity(0.8)
                )
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
                70
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

    private func updateGameCollision() {

        switch controller.controlMode {


        // --------------------------------------------------
        // Physical Eduard
        // --------------------------------------------------

        case .real:

            guard let pose =
                controller.realRobotPose

            else {
                return
            }


            gameController
                .updateRobotPose(
                    pose
                )


        // --------------------------------------------------
        // AR Eduard
        // --------------------------------------------------

        case .simulation:

            gameController
                .updateRobotPose(
                    controller
                        .eduardSimulation
                        .pose
                )


        // --------------------------------------------------
        // Synchronized
        // --------------------------------------------------

        case .synchronized:

            // The measured physical pose is authoritative
            // whenever it is available.

            if let pose =
                controller.realRobotPose {

                gameController
                    .updateRobotPose(
                        pose
                    )
            }

            else {

                // Useful fallback for testing without
                // the physical Eduard.

                gameController
                    .updateRobotPose(
                        controller
                            .eduardSimulation
                            .pose
                    )
            }
        }
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
