//
//  DragGestureView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//  https://github.com/michael94ellis/SwiftUIJoystick


import SwiftUI
import SwiftUIJoystick

public struct Joystick: View {
    
    private let baseSize: CGFloat = 220
    private let knobSize: CGFloat = 82
    
    
    /// The monitor object to observe the user input on the Joystick in XY or Polar coordinates
    @ObservedObject public var joystickMonitor: JoystickMonitor
    
    /// The width or diameter in which the Joystick will report values
    ///  For example: 100 will provide 0-100, with (50,50) being the origin
    private let dragDiameter: CGFloat
    /// Can be `.rect` or `.circle`
    /// Rect will allow the user to access the four corners
    /// Circle will limit Joystick it's radius determined by `dragDiameter / 2`
    private let shape: JoystickShape
    
    public init(monitor: JoystickMonitor, width: CGFloat, shape: JoystickShape = .rect) {
        self.joystickMonitor = monitor
        self.dragDiameter = width
        self.shape = shape
    }
    
    public var body: some View {
        VStack{
            JoystickBuilder(
                monitor: self.joystickMonitor,
                width: self.dragDiameter,
                shape: self.shape,
                background: {
                    ZStack {

                        Circle()
                            .fill(.white.opacity(0.1))
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.36), lineWidth: 2)
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
                    // Example Thumb
                    Image("EdukARtIllustration")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: knobSize,
                            height: knobSize)
                },
                locksInPlace: false)
        }
    }
}




#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        Joystick(
            monitor: JoystickMonitor(),
            width: 180,
            shape: .circle
        )
    }
}
