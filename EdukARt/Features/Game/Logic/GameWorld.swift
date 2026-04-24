//
//  GameWorld.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
// Player Eduard, Würfel als Obstacle

import Combine
import Foundation
import simd

final class GameWorld: ObservableObject {
    @Published var level: LevelData

    private let moveStep: Float = 0.02
    private var currentInput: ControlInput = .idle
    private var movementTimer: Timer?

    init() {
        level = LevelData(
            player: EduardPlayer(
                name: "Eduard",
                position: SIMD3<Float>(0, 0, 0)
            ),
            obstacles: [
                Obstacle(
                    name: "Cube Obstacle",
                    shape: .box,
                    position: SIMD3<Float>(0.3, 0, -0.6),
                    size: SIMD3<Float>(0.15, 0.15, 0.15)
                )
            ]
        )

        startMovementLoop()
    }

    deinit {
        movementTimer?.invalidate()
    }

    func updateInput(_ input: ControlInput) {
        currentInput = input
    }

    private func startMovementLoop() {
        movementTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.applyCurrentInput()
        }
    }

    private func applyCurrentInput() {
        if currentInput.isForwardPressed {
            level.player.position.z -= moveStep
        }

        if currentInput.isBackwardPressed {
            level.player.position.z += moveStep
        }

        if currentInput.isLeftPressed {
            level.player.position.x -= moveStep
        }

        if currentInput.isRightPressed {
            level.player.position.x += moveStep
        }
    }
}
