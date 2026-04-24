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

    /*
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
    */
    
    private func applyCurrentInput() {
        var candidatePosition = level.player.position

        if currentInput.isForwardPressed {
            candidatePosition.z -= moveStep
        }

        if currentInput.isBackwardPressed {
            candidatePosition.z += moveStep
        }

        if currentInput.isLeftPressed {
            candidatePosition.x -= moveStep
        }

        if currentInput.isRightPressed {
            candidatePosition.x += moveStep
        }

        if canMove(to: candidatePosition) {
            level.player.position = candidatePosition
        }
    }
    
    // check if move is possible or if there is an object blocking it
    private func canMove(to candidatePosition: SIMD3<Float>) -> Bool {
        let playerHalfSize = level.player.collisionSize / 2

        let playerMin = candidatePosition - playerHalfSize
        let playerMax = candidatePosition + playerHalfSize

        for obstacle in level.obstacles {
            let obstacleCenter = obstacle.position + SIMD3<Float>(0, obstacle.size.y / 2, 0)
            let obstacleHalfSize = obstacle.size / 2

            let obstacleMin = obstacleCenter - obstacleHalfSize
            let obstacleMax = obstacleCenter + obstacleHalfSize

            let overlapsX = playerMin.x <= obstacleMax.x && playerMax.x >= obstacleMin.x
            let overlapsY = playerMin.y <= obstacleMax.y && playerMax.y >= obstacleMin.y
            let overlapsZ = playerMin.z <= obstacleMax.z && playerMax.z >= obstacleMin.z

            if overlapsX && overlapsY && overlapsZ {
                return false
            }
        }

        return true
    }

}



