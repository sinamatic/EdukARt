//
//  UIRobotSettings.swift
//  EdukARt
//

import SwiftUI
import UIKit

struct UIRobotSettings: View {
    @ObservedObject var controller: EduardRemoteControlController
    let onBack: () -> Void

    @State private var areSettingsExpanded = false
    @State private var areLightsExpanded = false
    @State private var isRemoteControlExpanded = true

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

                settingsContent(isLandscape: isLandscape)
                    .padding(.horizontal, 24)
                    .padding(.top, isLandscape ? 72 : 86)
            }
        }
        .onChange(of: controller.connectionState) { _, state in
            guard state == .enabled else {
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                areSettingsExpanded = false
            }
        }
        .onChange(of: areSettingsExpanded) { _, isExpanded in
            guard isExpanded else {
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                isRemoteControlExpanded = false
            }
        }
        .onChange(of: areLightsExpanded) { _, isExpanded in
            guard isExpanded else {
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                isRemoteControlExpanded = false
            }
        }
    }

    @ViewBuilder
    private func settingsContent(isLandscape: Bool) -> some View {
        if isLandscape {
            landscapeLayout
        } else {
            portraitLayout
        }
    }

    private var landscapeLayout: some View {
        HStack(alignment: .top, spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    settingsSection
                    lightSection
                    remoteControlSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
            .scrollIndicators(.hidden)
            .scrollDisabled(isRemoteControlExpanded)

            Spacer(minLength: 24)

            VStack {
                Spacer()
                remoteDriveControls
                Spacer()
            }
            .frame(width: 290)
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var portraitLayout: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    settingsSection
                    lightSection
                    remoteControlSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(isRemoteControlExpanded)

            Spacer(minLength: 24)

            remoteDriveControls
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var connectionIndicator: some View {
        Circle()
            .fill(connectionColor)
            .frame(width: 11, height: 11)
            .accessibilityLabel(controller.connectionState.title)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                toggleSettingsSection()
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

    private var lightSection: some View {
        UIRobotLights(
            lightController: controller.lightController,
            isExpanded: $areLightsExpanded,
            isConnected: controller.isConnected,
            onToggleExpansion: {
                toggleLightsSection()
            },
            onSelectMode: { mode in
                controller.sendLightMode(mode)
            }
        )
    }

    private var remoteControlSection: some View {
        UIRobotDrive(
            controller: controller,
            isExpanded: $isRemoteControlExpanded,
            showsDriveControls: false,
            onToggleExpansion: {
                toggleRemoteControlSection()
            }
        )
    }

    @ViewBuilder
    private var remoteDriveControls: some View {
        UIRobotDrive(
            controller: controller,
            isExpanded: $isRemoteControlExpanded,
            showsHeader: false,
            onToggleExpansion: {
                toggleRemoteControlSection()
            }
        )
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

    private func toggleSettingsSection() {
        withAnimation(.easeInOut(duration: 0.2)) {
            areSettingsExpanded.toggle()

            if areSettingsExpanded {
                isRemoteControlExpanded = false
            }
        }
    }

    private func toggleLightsSection() {
        withAnimation(.easeInOut(duration: 0.2)) {
            areLightsExpanded.toggle()

            if areLightsExpanded {
                isRemoteControlExpanded = false
            }
        }
    }

    private func toggleRemoteControlSection() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isRemoteControlExpanded.toggle()

            if isRemoteControlExpanded {
                areSettingsExpanded = false
                areLightsExpanded = false
            }
        }
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

struct RemoteBackButtonStyle: ButtonStyle {
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

struct RemoteControlButtonStyle: ButtonStyle {
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
