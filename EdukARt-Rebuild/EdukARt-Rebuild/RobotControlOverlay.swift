//
//  RobotControlOverlay.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 26.08.26.
//

import SwiftUI

struct RobotControlOverlay: View {
    @ObservedObject var controller: RobotController

    var body: some View {
        HStack(spacing: 7) {
            Button {
                controller.toggleEnabled()
            } label: {
                Image(systemName: "power")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 34, height: 34)
                    .accessibilityLabel(controller.isEnabled ? "Disable" : "Enable")
            }
            .buttonStyle(RobotStatusIconButtonStyle(isEnabled: controller.isEnabled))

            Button {
                controller.checkConnection()
            } label: {
                trafficLight
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 7)
        .padding(.trailing, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(20)
        .offset(y: -20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Robot Status: WiFi \(controller.isWifiReachable), Enabled \(controller.isEnabled)")
        .onAppear { controller.checkConnection() }
    }

    private var trafficLight: some View {
        VStack(spacing: 4) {
            statusDot(.red, controller.isWifiReachable == false)
            statusDot(.yellow, controller.isWifiReachable && controller.isEnabled == false)
            statusDot(.green, controller.isEnabled)
        }
    }

    private func statusDot(_ color: Color, _ isActive: Bool) -> some View {
        Circle()
            .fill(color.opacity(isActive ? 1 : 0.1))
            .frame(width: 7, height: 7)
            .overlay(Circle().stroke(.white.opacity(isActive ? 0.62 : 0.1), lineWidth: 1))
    }
}

struct RobotStatusIconButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background((isEnabled ? Color.red.opacity(0.86) : .white.opacity(0.14)).opacity(configuration.isPressed ? 0.68 : 1))
            .foregroundStyle(.white)
            .clipShape(Circle())
    }
}
