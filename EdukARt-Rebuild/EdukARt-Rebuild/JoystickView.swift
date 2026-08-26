//
//  JoystickView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//  https://github.com/michael94ellis/SwiftUIJoystick


import SwiftUI
import SwiftUIJoystick

public struct JoystickView: View {
    
    private let knobSize: CGFloat = 82
    
    
    /// The monitor object to observe the user input on the Joystick in XY or Polar coordinates
    @ObservedObject public var joystickMonitor: JoystickMonitor
    @ObservedObject public var turnJoystickMonitor: JoystickMonitor
    
    /// The width or diameter in which the Joystick will report values
    ///  For example: 100 will provide 0-100, with (50,50) being the origin
    private let dragDiameter: CGFloat
    /// Can be `.rect` or `.circle`
    /// Rect will allow the user to access the four corners
    /// Circle will limit Joystick it's radius determined by `dragDiameter / 2`
    private let shape: JoystickShape
    
    public init(
        joystickMonitor: JoystickMonitor,
        turnJoystickMonitor: JoystickMonitor,
        width: CGFloat,
        shape: JoystickShape = .rect
    ) {
        self.joystickMonitor = joystickMonitor
        self.turnJoystickMonitor = turnJoystickMonitor
        self.dragDiameter = width
        self.shape = shape
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 40) {
            JoystickBuilder(
                monitor: turnJoystickMonitor,
                width: 120,
                shape: .rect,
                background: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 50)
                            .fill(.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 50)
                                    .stroke(
                                        .white.opacity(0.36),
                                        lineWidth: 2
                                    )
                            )
                        
                        Image(systemName: "arrow.counterclockwise")
                            .offset(x: -40)
                        
                        Image(systemName: "arrow.clockwise")
                            .offset(x: 40)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 150, height: 70)
                },
                foreground: {
                    Circle()
                        .fill(.brandGreen.opacity(0.9))
                        .frame(width: 32, height: 32)
                },
                locksInPlace: false
            )
            .frame(width: 120, height: 70)
            .offset(x: 10)
            
            JoystickBuilder(
                monitor: joystickMonitor,
                width: dragDiameter,
                shape: shape,
                background: {
                    ZStack {
                        
                        Circle()
                            .fill(.white.opacity(0.1))
                            .overlay(
                                Circle()
                                    .stroke(
                                        .white.opacity(0.36),
                                        lineWidth: 2
                                    )
                            )
                        
                        Image(systemName: "arrowtriangle.up.fill")
                            .offset(y: -60)
                        
                        Image(systemName: "arrowtriangle.down.fill")
                            .offset(y: 60)
                        
                        Image(systemName: "arrowtriangle.left.fill")
                            .offset(x: -60)
                        
                        Image(systemName: "arrowtriangle.right.fill")
                            .offset(x: 60)
                    }
                    .foregroundStyle(.white.opacity(0.75))
                },
                foreground: {
                    Image("EdukARtIllustration")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: knobSize,
                            height: knobSize
                        )
                },
                locksInPlace: false
            )
        }
        .padding(.bottom, 10)
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        JoystickView(
            joystickMonitor: JoystickMonitor(),
            turnJoystickMonitor: JoystickMonitor(),
            width: 180,
            shape: .circle
        )
    }
}
