//
//  RobotRemoteControlView.swift
//  EdukARt
//

import SwiftUI

struct RobotRemoteControlScreen: View {
    @ObservedObject var controller: RobotRemoteController
    let onBack: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        Button("Zurueck") {
                            onBack()
                        }
                        .buttonStyle(RemoteBackButtonStyle())

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    Spacer()
                }

                RobotRemoteControlView(
                    controller: controller,
                    isLandscape: isLandscape,
                    usesFullScreenLayout: true
                )
                .padding(.horizontal, 24)
                .padding(.top, isLandscape ? 72 : 86)
            }
        }
    }
}

struct RobotRemoteControlView: View {
    @ObservedObject var controller: RobotRemoteController
    let isLandscape: Bool
    var usesFullScreenLayout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Robot Remote Control")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                connectionIndicator
            }

            Text(controller.statusMessage)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(controller.isConnected ? "Disconnect" : "Connect") {
                    if controller.isConnected {
                        controller.disconnect()
                    } else {
                        controller.connect()
                    }
                }
                .buttonStyle(RemoteControlButtonStyle(fillColor: .white.opacity(0.16), foregroundColor: .white))

                Button("Enable") {
                    controller.sendEnable()
                }
                .buttonStyle(RemoteControlButtonStyle(fillColor: controller.isEnabled ? .green.opacity(0.82) : .yellow.opacity(0.9), foregroundColor: .black))

                Button(controller.isDrivingForward ? "Stop Forward" : "Drive-Forward") {
                    controller.toggleDriveForward()
                }
                .buttonStyle(RemoteControlButtonStyle(fillColor: controller.isDrivingForward ? .red.opacity(0.82) : .green.opacity(0.82), foregroundColor: controller.isDrivingForward ? .white : .black))
            }

            Spacer()
        }
        .padding(usesFullScreenLayout ? 0 : 16)
        .frame(width: usesFullScreenLayout ? nil : (isLandscape ? 340 : 320))
        .frame(maxWidth: usesFullScreenLayout ? .infinity : nil, maxHeight: usesFullScreenLayout ? .infinity : nil, alignment: .topLeading)
        .background(usesFullScreenLayout ? Color.clear : .black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: usesFullScreenLayout ? 0 : 18, style: .continuous))
    }

    private var connectionIndicator: some View {
        Circle()
            .fill(controller.isConnected ? .green : .white.opacity(0.35))
            .frame(width: 10, height: 10)
            .accessibilityLabel(controller.isConnected ? "Connected" : "Disconnected")
    }
}

private struct RemoteControlButtonStyle: ButtonStyle {
    let fillColor: Color
    let foregroundColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(minWidth: 76)
            .background(fillColor.opacity(configuration.isPressed ? 0.72 : 1))
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }
}

private struct RemoteBackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.18 : 0.12))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
