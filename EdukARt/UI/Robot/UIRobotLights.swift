//
//  UIRobotLights.swift
//  EdukARt
//

import SwiftUI
import UIKit

struct UIRobotLights: View {
    
    @ObservedObject var controller: RobotController
    @Binding var isExpanded: Bool
    
    @State private var allLightsColor = Color.orange
    @State private var signalColor = Color.orange
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "lightbulb.2")
                    
                    Text("Lights")
                        .font(.subheadline.weight(.bold))
                    
                    Spacer()
                    
                    Text(controller.lightController.activeMode.title)
                        .font(.caption)
                        .foregroundStyle(
                            controller.isConnected
                            ? .yellow
                            : .white.opacity(0.42)
                        )
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(
                            .degrees(isExpanded ? 0 : -90)
                        )
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    
                    carLights
                    
                    allLights
                    
                    signalLights
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    
    private var carLights: some View {
        lightSection(
            title: "Car Mode",
            modes: [
                .enabled,
                .loading
            ]
        )
    }
    
    
    private var allLights: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Text("All Lights")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
            
            UIColorPicker(
                title: "Color",
                color: $allLightsColor
            )
            .disabled(controller.isConnected == false)
            .onChange(of: allLightsColor) { _, color in
                setAllLightsColor(color)
            }
            
            lightButtons(
                modes: [
                    .solid,
                    .rainbowSolid,
                    .connectionLost,
                    .rotation,
                    .running,
                    .rainbow
                ]
            )
        }
    }
    
    
    private var signalLights: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Text("Blinker")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
            
            UIColorPicker(
                title: "Blinker Color",
                color: $signalColor
            )
            .disabled(controller.isConnected == false)
            .onChange(of: signalColor) { _, color in
                setSignalColor(color)
            }
            
            lightButtons(
                modes: [
                    .flashLeft,
                    .flashRight
                ]
            )
        }
    }
    
    
    private func lightSection(
        title: String,
        modes: [LightController.StandardMode]
    ) -> some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
            
            lightButtons(modes: modes)
        }
    }
    
    
    private func lightButtons(
        modes: [LightController.StandardMode]
    ) -> some View {
        
        LazyVGrid(columns: columns, spacing: 8) {
            
            ForEach(modes) { mode in
                
                Button {
                    controller.sendLightMode(mode)
                } label: {
                    VStack(spacing: 6) {
                        
                        Image(systemName: mode.systemImageName)
                            .font(.headline)
                        
                        Text(mode.title)
                            .font(.caption2.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                }
                .buttonStyle(
                    LightModeButtonStyle(
                        isSelected: controller.lightController.activeMode == mode,
                        isEnabled: controller.isConnected && mode.isFirmwareImplemented
                    )
                )
                .disabled(
                    controller.isConnected == false ||
                    mode.isFirmwareImplemented == false
                )
            }
        }
    }
    
    
    private func setAllLightsColor(_ color: Color) {
        let uiColor = UIColor(color)
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        
        uiColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: nil
        )
        
        controller.lightController.setAllLightsColor(
            red: Int((red * 255).rounded()),
            green: Int((green * 255).rounded()),
            blue: Int((blue * 255).rounded())
        )
    }
    
    
    private func setSignalColor(_ color: Color) {
        let uiColor = UIColor(color)
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        
        uiColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: nil
        )
        
        controller.lightController.setSignalColor(
            red: Int((red * 255).rounded()),
            green: Int((green * 255).rounded()),
            blue: Int((blue * 255).rounded())
        )
    }
}


private struct LightModeButtonStyle: ButtonStyle {
    
    let isSelected: Bool
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .background(
                backgroundColor
                    .opacity(configuration.isPressed ? 0.72 : 1)
            )
            .foregroundStyle(textColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    
    private var backgroundColor: Color {
        if isSelected && isEnabled {
            return .yellow.opacity(0.9)
        }
        
        return .white.opacity(isEnabled ? 0.14 : 0.05)
    }
    
    
    private var textColor: Color {
        if isSelected && isEnabled {
            return .black
        }
        
        return .white.opacity(isEnabled ? 1 : 0.34)
    }
}
