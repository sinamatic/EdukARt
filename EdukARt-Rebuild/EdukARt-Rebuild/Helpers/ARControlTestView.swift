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
    @StateObject private var sidewaysJoystickMonitor = JoystickMonitor()

    var body: some View {
        ZStack {

            CameraARView(
                eduardModelStore: eduardModelStore,
                joystickMonitor: joystickMonitor,
                sidewaysJoystickMonitor: sidewaysJoystickMonitor
            )
            Text(
                "Forward: \(joystickMonitor.xyPoint.y, specifier: "%.1f")  Sideways: \(sidewaysJoystickMonitor.xyPoint.x, specifier: "%.1f")"
            )
            .font(.caption)
            .ignoresSafeArea()

            VStack {
                Spacer()

                JoystickView(
                    joystickMonitor: joystickMonitor,
                    sidewaysJoystickMonitor: sidewaysJoystickMonitor,
                    width: 180,
                    shape: .circle
                )
                
//                Text(
//                    "Rotation X: \(sidewaysJoystickMonitor.xyPoint.x, specifier: "%.1f")"
//                )
//                .font(.caption)
//                .padding(.bottom, 10)
            }
        }
    }
}
