//
//  UIRobotSettings.swift
//  EdukARt
//

import SwiftUI
import UIKit

struct UIRobotSettings: View {
    
    @ObservedObject var controller: RobotController
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Settings")
                        .font(.subheadline.weight(.bold))
                    
                    
                   
                    
                    Spacer()
                    
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(
                            .degrees(isExpanded ? 0 : -90)
                        )
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    
                    Text("Connect your device to Eduard's WiFi network.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                    
                    Text(controller.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                    
                    HStack(spacing: 8) {
                        Button {
                            openWiFiSettings()
                        } label: {
                            settingsActionLabel(
                                title: "WiFi",
                                systemName: "wifi"
                            )
                        }
                        
                        
                        Button {
                            controller.sendEnable()
                        } label: {
                            settingsActionLabel(
                                title: "Enable",
                                systemName: "power"
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    
    private func settingsActionLabel(
        title: String,
        systemName: String
    ) -> some View {
        Label(title, systemImage: systemName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.white.opacity(0.14))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
    
    
    private func openWiFiSettings() {
        guard let settingsURL = URL(
            string: UIApplication.openSettingsURLString
        ) else {
            return
        }
        
        UIApplication.shared.open(settingsURL)
    }
}
