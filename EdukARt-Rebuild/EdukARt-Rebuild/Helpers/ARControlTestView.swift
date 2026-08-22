//
//  ARControlTestView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 22.08.26.
//

import SwiftUI
import SwiftUIJoystick

struct ARControlTestView: View {

    @ObservedObject var eduardModelStore: EduardModelStore

    @StateObject private var joystickMonitor = JoystickMonitor()
    @StateObject private var turnJoystickMonitor = JoystickMonitor()

    var body: some View {
        ZStack {

            CameraARView(
                eduardModelStore: eduardModelStore,
                joystickMonitor: joystickMonitor,
                turnJoystickMonitor: turnJoystickMonitor
            )
            Text(
                "Forward: \(joystickMonitor.xyPoint.y, specifier: "%.1f")  Sideways: \(joystickMonitor.xyPoint.x, specifier: "%.1f")  Turn: \(turnJoystickMonitor.xyPoint.x, specifier: "%.1f")"
            )
            .font(.caption)
            .ignoresSafeArea()

            VStack {
                Spacer()

                JoystickView(
                    joystickMonitor: joystickMonitor,
                    turnJoystickMonitor: turnJoystickMonitor,
                    width: 180,
                    shape: .circle
                )
            }
        }
    }
}
