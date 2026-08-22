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
//    @StateObject private var rotationJoystickMonitor = JoystickMonitor()

    var body: some View {
        ZStack {

            CameraARView(
                eduardModelStore: eduardModelStore,
                joystickMonitor: joystickMonitor
//                rotationJoystickMonitor: rotationJoystickMonitor
            )
            Text(
                "Drive X: \(joystickMonitor.xyPoint.x, specifier: "%.1f")  Y: \(joystickMonitor.xyPoint.y, specifier: "%.1f")"
            )
            .font(.caption)
            .ignoresSafeArea()

            VStack {
                Spacer()

                JoystickView(
                    joystickMonitor: joystickMonitor,
                    width: 180,
                    shape: .circle
                )
                
//                Text(
//                    "Rotation X: \(rotationJoystickMonitor.xyPoint.x, specifier: "%.1f")"
//                )
//                .font(.caption)
//                .padding(.bottom, 10)
            }
        }
    }
}
