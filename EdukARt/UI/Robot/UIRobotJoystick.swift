//
//  UIRobotJoystick.swift
//  EdukARt
//

import SwiftUI

struct UIRobotJoystick: View {
    
    var controller: RobotController?
    let onInputChanged: (CGPoint) -> Void
    
    @State private var knobOffset: CGSize = .zero
    
    private let baseSize: CGFloat = 220
    private let knobSize: CGFloat = 82
    private let maxOffset: CGFloat = 76
    
    var body: some View {
        ZStack {
            
            if controller?.driveMode == .mechanum {
                rotationButtons
            }
            
            joystick
        }
        .frame(
            width: controller == nil ? baseSize : 320,
            height: baseSize
        )
    }
    
    
    private var joystick: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.1))
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.36), lineWidth: 2)
                )
            
            crosshair
            
            Image("EdukARtIllustration")
                .resizable()
                .scaledToFit()
                .padding(2)
                .frame(
                    width: knobSize,
                    height: knobSize
                )
                .offset(knobOffset)
        }
        .frame(
            width: baseSize,
            height: baseSize
        )
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let offset = limitedOffset(
                        value.translation
                    )
                    
                    knobOffset = offset
                    
                    onInputChanged(
                        CGPoint(
                            x: offset.width / maxOffset,
                            y: offset.height / maxOffset
                        )
                    )
                }
                .onEnded { _ in
                    withAnimation {
                        knobOffset = .zero
                    }
                    
                    onInputChanged(.zero)
                }
        )
    }
    
    
    private var rotationButtons: some View {
        HStack {
            rotationButton(
                systemName: "arrow.counterclockwise",
                direction: .left
            )
            
            Spacer()
            
            rotationButton(
                systemName: "arrow.clockwise",
                direction: .right
            )
        }
        .frame(width: 320, height: baseSize, alignment: .bottom)
    }
    
    
    private func rotationButton(
        systemName: String,
        direction: RobotController.RotationDirection
    ) -> some View {
        
        Button {
        } label: {
            Image(systemName: systemName)
                .font(.title3.weight(.bold))
                .frame(width: 56, height: 44)
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.14))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    controller?.startMechanumRotation(direction)
                }
                .onEnded { _ in
                    controller?.stopMechanumRotation()
                }
        )
    }
    
    
    private var crosshair: some View {
        ZStack {
            
            Rectangle()
                .frame(width: 4, height: 28)
                .offset(y: -80)
            
            Rectangle()
                .frame(width: 4, height: 28)
                .offset(y: 80)
            
            Rectangle()
                .frame(width: 28, height: 4)
                .offset(x: -80)
            
            Rectangle()
                .frame(width: 28, height: 4)
                .offset(x: 80)
        }
        .foregroundStyle(.white.opacity(0.75))
    }
    
    
    private func limitedOffset(
        _ translation: CGSize
    ) -> CGSize {
        
        let distance = sqrt(
            translation.width * translation.width +
            translation.height * translation.height
        )
        
        if distance <= maxOffset {
            return translation
        }
        
        let scale = maxOffset / distance
        
        return CGSize(
            width: translation.width * scale,
            height: translation.height * scale
        )
    }
}
