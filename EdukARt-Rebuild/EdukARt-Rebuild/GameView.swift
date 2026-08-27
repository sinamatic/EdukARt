//
//  GameView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 23.08.26.
// Combined SwiftUI with AR World
//

import SwiftUI
import SwiftUIJoystick

struct GameView: View {

    @ObservedObject var eduardModelStore:
        EduardModelStore

    @ObservedObject var controller:
        RobotController

    let map:
            GameMap

    @State private var isMapLocalized =
        false
    
    
    // MARK: - Joystick

    @StateObject private var joystickMonitor =
        JoystickMonitor()

    @StateObject private var turnJoystickMonitor =
        JoystickMonitor()
    


    // MARK: - AprilTag Map

    @StateObject private var mapBuilder = AprilTagMapBuilder()

    var body: some View {

        gameContent
            .onChange(
                of:
                    joystickMonitor.xyPoint,
                handleDriveJoystickChange
            )
            .onChange(
                of:
                    turnJoystickMonitor.xyPoint,
                handleTurnJoystickChange
            )
    }


    private var gameContent: some View {

        ZStack {

            arView
            savedMapView
            localizationHeading
            arRobotControl
            joystickControl
        }
    }


    private func handleDriveJoystickChange(
        _ oldValue: CGPoint,
        _ point: CGPoint
    ) {

        controller.updateJoystickInput(
            x:
                Float(point.x / 180),

            y:
                Float(point.y / 180)
        )
    }


    private func handleTurnJoystickChange(
        _ oldValue: CGPoint,
        _ point: CGPoint
    ) {

        controller.updateMechanumRotationInput(
            x:
                Float(point.x / 120)
        )
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

        GameMapPreview(
            map:
                map,

            robotPose:
                controller.realRobotPose
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

        HStack(
            spacing:
                7
        ) {

            Button {

                controller
                    .placeSimulationAtReference()

            } label: {

                Image(
                    systemName:
                        "arkit"
                )
                .font(
                    .subheadline.weight(
                        .bold
                    )
                )
                .frame(
                    width:
                        34,

                    height:
                        34
                )
                .accessibilityLabel(
                    "Place AR Robot at Reference"
                )
            }
            .buttonStyle(
                RobotStatusIconButtonStyle(
                    isEnabled:
                        controller.realRobotPose != nil
                )
            )


            Toggle(
                "Live Sync",
                isOn:
                    $controller.isLiveSyncEnabled
            )
            .font(
                .caption.bold()
            )
            .foregroundStyle(
                .white
            )
            .toggleStyle(
                .switch
            )
        }
        .padding(
            .leading,
            7
        )
        .padding(
            .trailing,
            8
        )
        .padding(
            .vertical,
            5
        )
        .background(
            .black.opacity(
                0.58
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
        .frame(
            width:
                170
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
            20
        )
        .offset(
            y:
                -70
        )
    }


    // MARK: - Joystick

    @ViewBuilder
    private var joystickControl: some View {

        if isMapLocalized {

            VStack {

                Spacer()

                JoystickView(
                    joystickMonitor:
                        joystickMonitor,

                    turnJoystickMonitor:
                        turnJoystickMonitor,

                    width: 180,

                    shape: .circle
                )
            }
        }
    }
}
