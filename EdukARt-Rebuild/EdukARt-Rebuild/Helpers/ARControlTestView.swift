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
    @StateObject private var rotationJoystickMonitor = JoystickMonitor()

    var body: some View {
        ZStack {

            CameraARView(
                eduardModelStore: eduardModelStore,
                joystickMonitor: joystickMonitor,
                rotationJoystickMonitor: rotationJoystickMonitor
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                JoystickView(
                    joystickMonitor: joystickMonitor,
                    rotationJoystickMonitor: rotationJoystickMonitor,
                    width: 180,
                    shape: .circle
                )
                .padding(.bottom, 10)
            }
        }
    }
}
