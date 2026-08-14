//
//  UIRobotDrive.swift
//  EdukARt
//

import SwiftUI

struct UIRobotDrive: View {
    
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
                    Text("Drive")
                        .font(.subheadline.weight(.bold))
                    
                    Spacer()
                    
                    Text(controller.driveMode.rawValue)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(
                            .degrees(isExpanded ? 0 : -90)
                        )
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            
            
            if isExpanded {
                VStack(spacing: 18) {
                    
                    driveModePicker
                    
                    UIRobotJoystick(controller: controller) { input in
                        controller.updateJoystickInput(
                            x: Float(input.x),
                            y: Float(input.y)
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onChange(of: isExpanded) { _, expanded in
            if expanded == false {
                controller.stopJoystick()
            }
        }
    }
    
    
    private var driveModePicker: some View {
        Picker(
            "Drive Mode",
            selection: Binding(
                get: {
                    controller.driveMode
                },
                set: { mode in
                    controller.setDriveMode(mode)
                }
            )
        ) {
            ForEach(RobotController.DriveMode.allCases) { mode in
                Text(mode.rawValue)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
    
}
