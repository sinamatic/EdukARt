//
//  UIRobotControl.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 13.08.26.
//
import SwiftUI

struct UIRobotControl: View {
    
    @ObservedObject var controller: RobotController
    
    @State private var settingsExpanded = false
    @State private var driveExpanded = true
    @State private var lightsExpanded = false
    
    var body: some View {
        ZStack {
            
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 12) {
                    UIRobotSettings(
                        controller: controller,
                        isExpanded: $settingsExpanded
                    )
                                                          
                    UIRobotDrive(
                        controller: controller,
                        isExpanded: $driveExpanded
                    )
                    
                    UIRobotLights(
                        controller: controller,
                        isExpanded: $lightsExpanded
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func toggleSettings() {
        settingsExpanded.toggle()
        
        if settingsExpanded {
            driveExpanded = false
            lightsExpanded = false
        }
    }
    
    
    private func toggleDrive() {
        driveExpanded.toggle()
        
        if driveExpanded {
            settingsExpanded = false
            lightsExpanded = false
        }
    }
    
    
    private func toggleLights() {
        lightsExpanded.toggle()
        
        if lightsExpanded {
            settingsExpanded = false
            driveExpanded = false
        }
    }
}
