//
//  UIRobotStatusOverlay.swift
//  EdukARt
//

import SwiftUI

struct UIRobotStatusOverlay: View {
    @ObservedObject var controller: EduardRemoteControlController

    var body: some View {
        HStack(spacing: 8) {
            trafficLight

            Button {
                controller.sendDisable()
            } label: {
                Image(systemName: "power")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 34, height: 34)
                    .accessibilityLabel("Disable")
            }
            .buttonStyle(RobotStatusIconButtonStyle(isEnabled: controller.isEnabled))
            .disabled(controller.isConnected == false)
            .opacity(controller.isConnected ? 1 : 0.45)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Robot Status: \(controller.connectionState.title)")
    }

    private var trafficLight: some View {
        HStack(spacing: 5) {
            statusDot(color: .red, isActive: controller.connectionState == .disconnected)
            statusDot(color: .yellow, isActive: controller.connectionState == .connected)
            statusDot(color: .green, isActive: controller.connectionState == .enabled)
        }
    }

    private func statusDot(color: Color, isActive: Bool) -> some View {
        Circle()
            .fill(color.opacity(isActive ? 1 : 0.24))
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(.white.opacity(isActive ? 0.62 : 0.18), lineWidth: 1)
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
