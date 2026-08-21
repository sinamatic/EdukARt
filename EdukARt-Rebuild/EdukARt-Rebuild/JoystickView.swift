//
//  JoystickView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//

import SwiftUI

struct JoystickView: View {
    let onChange: (JoystickInput) -> Void

    @State private var dragOffset: CGSize = .zero

    private let size: CGFloat = 220
    private let knobSize: CGFloat = 78

    var body: some View {
        let radius = (size - knobSize) / 2

        ZStack {
            Circle()
                .fill(.white.opacity(0.08))
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 2)
                }

            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: knobSize, height: knobSize)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                }
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let clampedOffset = clamped(
                                value.translation,
                                radius: radius
                            )

                            dragOffset = clampedOffset
                            onChange(
                                JoystickInput(
                                    x: clampedOffset.width / radius,
                                    y: -clampedOffset.height / radius
                                )
                            )
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                dragOffset = .zero
                            }

                            onChange(
                                JoystickInput(
                                    x: 0,
                                    y: 0
                                )
                            )
                        }
                )
        }
        .frame(width: size, height: size)
    }

    private func clamped(
        _ offset: CGSize,
        radius: CGFloat
    ) -> CGSize {

        let distance = sqrt(
            offset.width * offset.width + offset.height * offset.height
        )

        guard distance > radius else {
            return offset
        }

        let scale = radius / distance
        return CGSize(
            width: offset.width * scale,
            height: offset.height * scale
        )
    }
}

struct JoystickInput {
    let x: CGFloat
    let y: CGFloat
}
