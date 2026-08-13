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
    private let crosshairLength: CGFloat = 28
    private let crosshairThickness: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.1))
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.36), lineWidth: 2)
                )

            crosshair

            robotKnob
                .offset(knobOffset)
        }
        .frame(width: baseSize, height: baseSize)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let limitedOffset = limitedKnobOffset(for: value.translation)
                    knobOffset = limitedOffset
                    onInputChanged(CGPoint(
                        x: limitedOffset.width / maxOffset,
                        y: limitedOffset.height / maxOffset
                    ))
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                        knobOffset = .zero
                    }

                    onInputChanged(.zero)
                }
        )
    }

    private var crosshair: some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(0.75))
                .frame(width: crosshairThickness, height: crosshairLength)
                .offset(y: -(baseSize / 2 - 30))

            Rectangle()
                .fill(.white.opacity(0.75))
                .frame(width: crosshairThickness, height: crosshairLength)
                .offset(y: baseSize / 2 - 30)

            Rectangle()
                .fill(.white.opacity(0.75))
                .frame(width: crosshairLength, height: crosshairThickness)
                .offset(x: -(baseSize / 2 - 30))

            Rectangle()
                .fill(.white.opacity(0.75))
                .frame(width: crosshairLength, height: crosshairThickness)
                .offset(x: baseSize / 2 - 30)
        }
    }

    private var robotKnob: some View {
        Image("EdukARtIllustration")
            .resizable()
            .scaledToFit()
            .padding(2)
            .frame(width: knobSize, height: knobSize)
            .shadow(color: .black.opacity(0.32), radius: 8, x: 0, y: 5)
            .accessibilityLabel("Eduard joystick handle")
    }

    private func limitedKnobOffset(for translation: CGSize) -> CGSize {
        let length = sqrt((translation.width * translation.width) + (translation.height * translation.height))

        guard length > maxOffset else {
            return translation
        }

        let scale = maxOffset / length
        return CGSize(
            width: translation.width * scale,
            height: translation.height * scale
        )
    }
}
