//
//  UIEduardControl.swift
//  EdukARt
//

import SwiftUI
import UIKit

struct RobotRemoteControlScreen: View {
    @ObservedObject var controller: EduardRemoteControlController
    let onBack: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        Button("Back") {
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
    @ObservedObject var controller: EduardRemoteControlController
    let isLandscape: Bool
    var usesFullScreenLayout = false

    @State private var areSettingsExpanded = true

    var body: some View {
        Group {
            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .padding(usesFullScreenLayout ? 0 : 16)
        .frame(width: usesFullScreenLayout ? nil : (isLandscape ? 340 : 320))
        .frame(maxWidth: usesFullScreenLayout ? .infinity : nil, maxHeight: usesFullScreenLayout ? .infinity : nil, alignment: .topLeading)
        .background(usesFullScreenLayout ? Color.clear : .black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: usesFullScreenLayout ? 0 : 18, style: .continuous))
        .onChange(of: controller.connectionState) { _, state in
            guard state == .enabled else {
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                areSettingsExpanded = false
            }
        }
    }

    private var landscapeLayout: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                settingsSection
                driveModePicker
                Spacer()
            }
            .frame(maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)

            Spacer(minLength: 24)

            VStack {
                Spacer()
                driveControls
                Spacer()
            }
            .frame(width: 260)
            .frame(maxHeight: .infinity)
        }
    }

    private var portraitLayout: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            settingsSection
            driveModePicker

            Spacer(minLength: 24)

            driveControls
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 28)
        }
    }

    private var headerSection: some View {
        HStack {
            Text("Robot Remote Control")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            connectionIndicator
        }
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

    private var driveControls: some View {
        VStack(spacing: 18) {
            RobotJoystickView { input in
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

    private var connectionIndicator: some View {
        Circle()
            .fill(connectionColor)
            .frame(width: 11, height: 11)
            .accessibilityLabel(controller.connectionState.title)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    areSettingsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Settings")
                        .font(.subheadline.weight(.bold))

                    Spacer()

                    Label(controller.connectionState.title, systemImage: "circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(connectionColor)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(areSettingsExpanded ? 0 : -90))
                }
                .foregroundStyle(.white)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if areSettingsExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Open WiFi Settings, connect to EduardBlue3, then confirm the established connection with Connected.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(controller.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button {
                            openWiFiSettings()
                        } label: {
                            Label("WiFi Settings", systemImage: "wifi")
                        }
                        .buttonStyle(RemoteControlButtonStyle(fillColor: .white.opacity(0.16), foregroundColor: .white))

                        Button {
                            controller.connect()
                        } label: {
                            Label("Connected", systemImage: controller.isConnected ? "checkmark.circle.fill" : "link")
                        }
                        .buttonStyle(RemoteControlButtonStyle(fillColor: controller.isConnected ? .yellow.opacity(0.9) : .white.opacity(0.16), foregroundColor: controller.isConnected ? .black : .white))

                        Button {
                            controller.sendEnable()
                        } label: {
                            Label("Enable", systemImage: controller.isEnabled ? "checkmark.circle.fill" : "power")
                        }
                        .buttonStyle(RemoteControlButtonStyle(fillColor: controller.isEnabled ? .green.opacity(0.82) : .yellow.opacity(0.9), foregroundColor: .black))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var connectionColor: Color {
        switch controller.connectionState {
        case .disconnected:
            return .red
        case .connected:
            return .yellow
        case .enabled:
            return .green
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

    private func openWiFiSettings() {
        guard let wiFiSettingsURL = URL(string: "App-Prefs:root=WIFI") else {
            if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettingsURL)
            }

            return
        }

        UIApplication.shared.open(wiFiSettingsURL) { didOpen in
            guard didOpen == false, let appSettingsURL = URL(string: UIApplication.openSettingsURLString) else {
                return
            }

            UIApplication.shared.open(appSettingsURL)
        }
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
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct RobotJoystickView: View {
    let onInputChanged: (CGPoint) -> Void

    @State private var knobOffset: CGSize = .zero

    private let baseSize: CGFloat = 190
    private let knobSize: CGFloat = 62
    private let maxOffset: CGFloat = 64
    private let crosshairLength: CGFloat = 24
    private let crosshairThickness: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.1))
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.36), lineWidth: 2)
                )

            crosshair

            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: knobSize, height: knobSize)
                .shadow(color: .black.opacity(0.32), radius: 8, x: 0, y: 5)
                .offset(knobOffset)
        }
        .frame(width: baseSize, height: baseSize)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let limitedOffset = limitedKnobOffset(for: value.translation)
                    knobOffset = limitedOffset
                    onInputChanged(CGPoint(
                        x: limitedOffset.width / maxOffset,
                        y: limitedOffset.height / maxOffset
                    ))
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                        knobOffset = .zero
                    }

                    onInputChanged(.zero)
                }
        )
    }

    private var crosshair: some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(0.75))
                .frame(width: crosshairThickness, height: crosshairLength)
                .offset(y: -(baseSize / 2 - 30))

            Rectangle()
                .fill(.white.opacity(0.75))
                .frame(width: crosshairThickness, height: crosshairLength)
                .offset(y: baseSize / 2 - 30)

            Rectangle()
                .fill(.white.opacity(0.75))
                .frame(width: crosshairLength, height: crosshairThickness)
                .offset(x: -(baseSize / 2 - 30))

            Rectangle()
                .fill(.white.opacity(0.75))
                .frame(width: crosshairLength, height: crosshairThickness)
                .offset(x: baseSize / 2 - 30)
        }
    }

    private func limitedKnobOffset(for translation: CGSize) -> CGSize {
        let length = sqrt((translation.width * translation.width) + (translation.height * translation.height))

        guard length > maxOffset else {
            return translation
        }

        let scale = maxOffset / length
        return CGSize(
            width: translation.width * scale,
            height: translation.height * scale
        )
    }
}
