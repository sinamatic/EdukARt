//
//  UIRobotDrive.swift
//  EdukARt
//

import SwiftUI

struct UIRobotDrive: View {
    @ObservedObject var controller: EduardRemoteControlController
    @Binding var isExpanded: Bool
    var showsHeader = true
    var showsDriveControls = true
    let onToggleExpansion: () -> Void

    var body: some View {
        Group {
            if showsHeader {
                remoteControlSection
            } else {
                remoteDriveControls
            }
        }
        .onChange(of: isExpanded) { _, isExpanded in
            guard isExpanded == false else {
                return
            }

            controller.stopJoystick()
        }
    }

    private var remoteControlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                onToggleExpansion()
            } label: {
                HStack {
                    Text("Remote Control")
                        .font(.subheadline.weight(.bold))

                    Spacer()

                    Text(controller.driveMode.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .foregroundStyle(.white)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                driveModePicker
                    .transition(.opacity.combined(with: .move(edge: .top)))

                if showsDriveControls {
                    driveControls
                        .transition(.opacity)
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var driveModePicker: some View {
        Picker("Drive Mode", selection: Binding(
            get: { controller.driveMode },
            set: { controller.setDriveMode($0) }
        )) {
            ForEach(EduardRemoteControlController.DriveMode.allCases) { mode in
                Text(mode.rawValue)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .tint(.white)
    }

    @ViewBuilder
    private var remoteDriveControls: some View {
        if isExpanded {
            driveControls
                .transition(.opacity)
        }
    }

    private var driveControls: some View {
        VStack(spacing: 18) {
            UIRobotJoystick { input in
                controller.updateJoystickInput(x: Float(input.x), y: Float(input.y))
            }

            if controller.driveMode == .mechanum {
                HStack(spacing: 12) {
                    rotationButton(
                        systemName: "arrow.counterclockwise",
                        label: "Counterclockwise",
                        direction: .left
                    )

                    rotationButton(
                        systemName: "arrow.clockwise",
                        label: "Clockwise",
                        direction: .right
                    )
                }
            }
        }
    }

    private func rotationButton(
        systemName: String,
        label: String,
        direction: EduardRemoteControlController.RotationDirection
    ) -> some View {
        Button {} label: {
            Image(systemName: systemName)
                .font(.title3.weight(.bold))
                .frame(width: 56, height: 44)
                .accessibilityLabel(label)
        }
        .buttonStyle(RemoteControlButtonStyle(fillColor: .white.opacity(0.14), foregroundColor: .white))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    controller.startMechanumRotation(direction)
                }
                .onEnded { _ in
                    controller.stopMechanumRotation()
                }
        )
    }
}
