//
//  DragGestureView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//

import SwiftUI
import SwiftUIJoystick
import UIKit

struct RobotRemoteView: View {
    
    @StateObject private var joystickMonitor = JoystickMonitor()
    @StateObject private var sidewaysJoystickMonitor = JoystickMonitor()
    
    @State private var settingsExpanded = false
    @State private var driveExpanded = true
    @State private var lightsExpanded = false
    @State private var cameraExpanded = false
    
    @State private var driveMode: DriveMode = .mecanum
    @State private var lightMode: LightMode = .enabled
    
    @State private var allLightsColor = Color.orange
    @State private var signalColor = Color.orange
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // expandable sections
            ScrollView {
                VStack(spacing: 12) {
                    
                    settingsSection
                    
                    lightsSection
                    
                    cameraSection
                    
                    driveSection // toDo remove scrollbar
                    
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Robot Remote")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Settings

private extension RobotRemoteView {
    
    var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Button {
                withAnimation {
                    settingsExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "gearshape")
                    Text("Settings")
                        .font(.subheadline.weight(.bold))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(
                            .degrees(settingsExpanded ? 0 : -90)
                        )
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            
            if settingsExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    
                    Text("Connect your device to Eduard's WiFi network.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                    // ToDo Ping Robot and check active WiFi Connection
                    
                    HStack(spacing: 8) {
                        
                        Button {
                            openWiFiSettings()
                        } label: {
                            Label("WiFi", systemImage: "wifi")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.14))
                                .foregroundStyle(.white)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 8)
                                )
                            // toDo change color to green when connected
                        }
                        
                        Button {
                            print("Enable Robot")
                        } label: {
                            Label("Enable", systemImage: "power")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.14))
                                .foregroundStyle(.white)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 8)
                                )
                            // toDo change color to green when enabled, maybe use light switch ros topic?
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Text("Drive Mode")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.68))
                    
                    Picker("Drive Mode", selection: $driveMode) {
                        ForEach(DriveMode.allCases) { mode in
                            Text(mode.title)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: driveMode) { _, mode in
                        print("Drive Mode:", mode.title)
                    }
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(
            RoundedRectangle(cornerRadius: 8)
        )
    }
    
    func openWiFiSettings() {
        print("Open WiFi Settings")
        
        guard let url = URL(
            string: UIApplication.openSettingsURLString // toDo check if Wifi settings can be opened, this opens App Settings?!
        ) else {
            return
        }
        
        UIApplication.shared.open(url)
    }
}

// MARK: - Drive

private extension RobotRemoteView {
    
    var driveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // ToDo remove scrollbar, interfers with Joystick
            
            Button {
                withAnimation {
                    driveExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "steeringwheel")
                    
                    Text("Drive")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)

                    
                    Spacer()
                    Text(driveMode.title)
                        .font(.caption)
                        .foregroundStyle(.brandGreen)
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(
                            .degrees(driveExpanded ? 0 : -90)
                        )
                }
                Spacer()
                
                .foregroundStyle(.white)
            }
            
                .buttonStyle(.plain)
            
            if driveExpanded {
                JoystickView(
                    joystickMonitor: joystickMonitor,
                    sidewaysJoystickMonitor: sidewaysJoystickMonitor,
                    width: 180,
                    shape: .circle
                )
                .frame(maxWidth: .infinity)

//                Text(
//                    "Rotation: \(sidewaysJoystickMonitor.xyPoint.x, specifier: "%.2f")"
//                )

                Text(
                    "Forward: \(joystickMonitor.xyPoint.y, specifier: "%.2f")   Sideways: \(sidewaysJoystickMonitor.xyPoint.x, specifier: "%.2f")"
                )
                .font(.caption)
                .frame(maxWidth: .infinity)
            }
            
            
           
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(
            RoundedRectangle(cornerRadius: 8)
        )
    }
}

// MARK: - Lights

private extension RobotRemoteView {
    
    var lightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            Button {
                withAnimation {
                    lightsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.2")
                    
                    Text("Lights")
                        .font(.subheadline.weight(.bold))
                    
                    Spacer()
                    
                    Text(lightMode.title)
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(
                            .degrees(lightsExpanded ? 0 : -90)
                        )
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            
            if lightsExpanded {
                carLightsSection
                allLightsSection
                signalLightsSection
            }
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(
            RoundedRectangle(cornerRadius: 8)
        )
    }
    
    var carLightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Text("Car Mode")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
            
            lightButtons([
                .enabled,
                .loading
            ])
        }
    }
    
    var allLightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Text("All Lights")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
            
            ColorPicker(
                "Color",
                selection: $allLightsColor,
                supportsOpacity: false
            )
            .foregroundStyle(.white)
            .onChange(of: allLightsColor) { _, color in
                print("All Lights Color:", color)
            }
            
            lightButtons([
                .slowBlinking,
                .fastBlinking,
                .running,
                .rainbowRunning
            ])
        }
    }
    
    var signalLightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Text("Blinker")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
            
            ColorPicker(
                "Blinker Color",
                selection: $signalColor,
                supportsOpacity: false
            )
            .foregroundStyle(.white)
            .onChange(of: signalColor) { _, color in
                print("Blinker Color:", color)
            }
            
            lightButtons([
                .flashLeft,
                .flashRight
            ])
        }
    }
    
    func lightButtons(
        _ modes: [LightMode]
    ) -> some View {
        
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 8
        ) {
            ForEach(modes) { mode in
                
                Button {
                    lightMode = mode
                    print("Light Mode:", mode.title)
                    
                } label: {
                    VStack(spacing: 6) {
                        
                        Image(systemName: mode.systemImage)
                        
                        Text(mode.title)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                }
                .buttonStyle(
                    LightButtonStyle(
                        isSelected: lightMode == mode
                    )
                )
            }
        }
    }
}

// MARK: - Camera

private extension RobotRemoteView {
    
    var cameraSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Button {
                withAnimation {
                    cameraExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                    
                    Text("Camera")
                        .font(.subheadline.weight(.bold))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(
                            .degrees(cameraExpanded ? 0 : -90)
                        )
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            
            if cameraExpanded {
                CameraPreviewView()
                    .frame(height: 220)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 8)
                    )
            }
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(
            RoundedRectangle(cornerRadius: 8)
        )
    }
}

// MARK: - Drive Mode

private enum DriveMode: String, CaseIterable, Identifiable {
    
    case mecanum
    case offroad
    
    var id: Self {
        self
    }
    
    var title: String {
        switch self {
        case .mecanum:
            return "Mecanum"
            
        case .offroad:
            return "Offroad"
        }
    }
}

// MARK: - Light Mode

private enum LightMode: String, CaseIterable, Identifiable {
    
    case enabled
    case loading
    case slowBlinking
    case fastBlinking
    case running
    case rainbowRunning
    case flashLeft
    case flashRight
    
    var id: Self {
        self
    }
    
    var title: String {
        switch self {
        case .enabled:
            return "Enabled Light"
            
        case .loading:
            return "Pulsation"
            
        case .slowBlinking:
            return "Slow Blinking"
            
        case .fastBlinking:
            return "Fast Blinking"
            
        case .running:
            return "Running Light"
            
        case .rainbowRunning:
            return "Rainbow Running"
            
        case .flashLeft:
            return "Left Signal"
            
        case .flashRight:
            return "Right Signal"
        }
    }
    
    var systemImage: String {
        switch self {
        case .enabled:
            return "checkmark.circle"
            
        case .loading:
            return "hourglass"
            
        case .slowBlinking:
            return "exclamationmark.triangle"
            
        case .fastBlinking:
            return "globe"
            
        case .running,
                .rainbowRunning:
            return "circle.hexagongrid.circle"
            
        case .flashLeft:
            return "arrowtriangle.left.fill"
            
        case .flashRight:
            return "arrowtriangle.right.fill"
        }
    }
}

// MARK: - Light Button Style

private struct LightButtonStyle: ButtonStyle {
    
    let isSelected: Bool
    
    func makeBody(
        configuration: Configuration
    ) -> some View {
        
        configuration.label
            .padding(.horizontal, 8)
            .background(
                isSelected
                ? .yellow.opacity(0.9)
                : .white.opacity(0.14)
            )
            .foregroundStyle(
                isSelected
                ? .black
                : .white
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 8)
            )
            .scaleEffect(
                configuration.isPressed ? 0.96 : 1
            )
            .animation(
                .easeOut(duration: 0.1),
                value: configuration.isPressed
            )
    }
}

#Preview {
    NavigationStack {
        RobotRemoteView()
    }
}
