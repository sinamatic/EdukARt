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

    // MARK: - Joystick

    @StateObject private var joystickMonitor =
        JoystickMonitor()

    @StateObject private var turnJoystickMonitor =
        JoystickMonitor()
    


    // MARK: - AprilTag Map

    @StateObject private var mapBuilder = AprilTagMapBuilder()
    @StateObject private var track = Track()

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
                    mapBuilder
            )
            .ignoresSafeArea()
            
            AprilTagMapView(
                mapBuilder: mapBuilder,
                track: track
            )


//            // MARK: - Debug Joystick Values
//
//            Text(
//                "Forward: \(joystickMonitor.xyPoint.y, specifier: "%.1f")  Sideways: \(joystickMonitor.xyPoint.x, specifier: "%.1f")  Turn: \(turnJoystickMonitor.xyPoint.x, specifier: "%.1f")"
//            )
//            .font(.caption)


            // MARK: - Joystick

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
