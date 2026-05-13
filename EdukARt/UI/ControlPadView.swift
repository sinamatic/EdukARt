//
//  ControlPadView.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import SwiftUI
import simd

struct ControlPadView: View {
    let onInputChanged: (ControlInput) -> Void

    @State private var knobOffset: CGSize = .zero

    private let baseSize: CGFloat = 140
    private let knobSize: CGFloat = 56
    private let maxOffset: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: baseSize, height: baseSize)

            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: knobSize, height: knobSize)
                .offset(knobOffset)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let translation = value.translation
                    let limitedOffset = limitedKnobOffset(for: translation)

                    knobOffset = limitedOffset
                    onInputChanged(makeInput(from: limitedOffset))
                }
                .onEnded { _ in
                    knobOffset = .zero
                    onInputChanged(.idle)
                }
        )
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

    private func makeInput(from offset: CGSize) -> ControlInput {
        let normalizedX = Float(offset.width / maxOffset)
        let normalizedY = Float(offset.height / maxOffset)

        return ControlInput(direction: SIMD2<Float>(normalizedY, -normalizedX))
    }
}
