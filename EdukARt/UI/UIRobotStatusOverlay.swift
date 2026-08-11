//
//  UIRobotStatusOverlay.swift
//  EdukARt
//

import SwiftUI

struct UIRobotStatusOverlay: View {
    @ObservedObject var controller: EduardRemoteControlController

    var body: some View {
        HStack(spacing: 7) {
            Button {
                if controller.isEnabled {
                    controller.sendDisable()
                } else {
                    controller.sendEnable()
                }
            } label: {
                Image(systemName: "power")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 34, height: 34)
                    .accessibilityLabel(controller.isEnabled ? "Disable" : "Enable")
            }
            .buttonStyle(RobotStatusIconButtonStyle(isEnabled: controller.isEnabled))

            trafficLight
        }
        .padding(.leading, 7)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Robot Status: \(controller.connectionState.title)")
    }

    private var trafficLight: some View {
        VStack(spacing: 4) {
            statusDot(color: .red, isActive: controller.connectionState == .disconnected)
            statusDot(color: .yellow, isActive: controller.connectionState == .connected)
            statusDot(color: .green, isActive: controller.connectionState == .enabled)
        }
    }

    private func statusDot(color: Color, isActive: Bool) -> some View {
        Circle()
            .fill(color.opacity(isActive ? 1 : 0.1))
            .frame(width: 7, height: 7)
            .overlay(
                Circle()
                    .stroke(.white.opacity(isActive ? 0.62 : 0.1), lineWidth: 1)
            )
    }
}

private struct RobotStatusIconButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(buttonFill.opacity(configuration.isPressed ? 0.68 : 1))
            .foregroundStyle(.white)
            .clipShape(Circle())
    }

    private var buttonFill: Color {
        isEnabled ? .red.opacity(0.86) : .white.opacity(0.14)
    }
}
