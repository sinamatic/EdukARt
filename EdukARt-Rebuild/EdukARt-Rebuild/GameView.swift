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

        ZStack {

            // MARK: - AR View

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


            // MARK: - Saved Game Map

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


            // MARK: - AR Robot Control

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
                maxWidth:
                    .infinity,

                maxHeight:
                    .infinity,

                alignment:
                    .topTrailing
            )
            .padding(
                .trailing,
                112
            )
            .padding(
                20
            )
            .offset(
                y:
                    -20
            )


//            // MARK: - Debug Joystick Values
//
//            Text(
//                "Forward: \(joystickMonitor.xyPoint.y, specifier: "%.1f")  Sideways: \(joystickMonitor.xyPoint.x, specifier: "%.1f")  Turn: \(turnJoystickMonitor.xyPoint.x, specifier: "%.1f")"
//            )
//            .font(.caption)


            // MARK: - Joystick

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


            // MARK: - AprilTag Map Overlay
            //
            // Add next:
            //
            // UIAprilTagMapOverlay(
            //     mapBuilder: mapBuilder
            // )
        }
    }
}
