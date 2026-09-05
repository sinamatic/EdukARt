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
        HStack(alignment: .bottom, spacing: 20) {
            TranslationJoystickControl(
                monitor: turnJoystickMonitor,
                width: 120,
                maximumMonitorValue: 120,
                background: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 35)
                            .fill(.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 35)
                                    .stroke(
                                        .white.opacity(0.36),
                                        lineWidth: 2
                                    )
                            )
                        
                        Image(systemName: "arrow.counterclockwise")
                            .offset(x: -34)
                        
                        Image(systemName: "arrow.clockwise")
                            .offset(x: 34)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 70)
                },
                foreground: {
                    Circle()
                        .fill(.brandGreen.opacity(0.9))
                        .frame(width: 32, height: 32)
                }
            )
            .frame(width: 120, height: 70)
            
            TranslationJoystickControl(
                monitor: joystickMonitor,
                width: dragDiameter,
                maximumMonitorValue: dragDiameter,
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
                }
            )
        }
        .padding(.bottom, 10)
        .padding(.horizontal, 8)
    }
}

private struct TranslationJoystickControl<Background: View, Foreground: View>: View {

    @ObservedObject var monitor:
        JoystickMonitor

    let width:
        CGFloat

    let maximumMonitorValue:
        CGFloat

    @ViewBuilder let background:
        () -> Background

    @ViewBuilder let foreground:
        () -> Foreground

    @State private var knobOffset:
        CGSize = .zero

    private var maxOffset:
        CGFloat {

        width / 2
    }

    var body: some View {

        ZStack {

            background()

            foreground()
                .offset(
                    knobOffset
                )
        }
        .contentShape(
            Rectangle()
        )
        .gesture(

            DragGesture(
                minimumDistance:
                    0
            )
            .onChanged { value in

                let distance =
                    sqrt(
                        value.translation.width
                            * value.translation.width
                        +
                        value.translation.height
                            * value.translation.height
                    )


                var offset =
                    value.translation


                if distance > maxOffset {

                    let scale =
                        maxOffset / distance

                    offset =
                        CGSize(
                            width:
                                value.translation.width
                                * scale,

                            height:
                                value.translation.height
                                * scale
                        )
                }


                knobOffset =
                    offset


                let input =
                    CGPoint(
                        x:
                            offset.width
                            / maxOffset
                            * maximumMonitorValue,

                        y:
                            offset.height
                            / maxOffset
                            * maximumMonitorValue
                    )


                monitor.xyPoint =
                    input
            }
            .onEnded { _ in

                withAnimation(
                    .easeOut(
                        duration:
                            0.15
                    )
                ) {

                    knobOffset =
                        .zero
                }


                monitor.xyPoint =
                    .zero
            }
        )
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
