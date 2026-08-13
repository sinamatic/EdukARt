//
//  UIRobotJoystick.swift
//  EdukARt
//

import SwiftUI

struct UIRobotJoystick: View {
    
    let onInputChanged: (CGPoint) -> Void
    
    @State private var knobOffset: CGSize = .zero
    
    private let baseSize: CGFloat = 220
    private let knobSize: CGFloat = 82
    private let maxOffset: CGFloat = 76
    
    var body: some View {
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
        .highPriorityGesture(
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
