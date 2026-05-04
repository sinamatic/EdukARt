//
//  GameWorld.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import Combine
import Foundation
import simd
import UIKit

final class Game: ObservableObject {
    @Published var collisionMessage: String?
    @Published var itemBoxMessage: String?
    @Published var isBlocked = false

    let currentScene: any GameScene
    let currentController: any ControlSource
    let currentRobot: any RobotTarget

    private let moveStep: Float = 0.02
    private var movementTimer: Timer?
    private var itemBoxMessageClearWorkItem: DispatchWorkItem?

    var canMoveInRealWorld: ((SIMD3<Float>, SIMD3<Float>) -> Bool)?

    init(
        currentScene: (any GameScene)? = nil,
        currentController: (any ControlSource)? = nil,
        currentRobot: (any RobotTarget)? = nil
    ) {
        let robot = currentRobot ?? SimulatedEduard(
            name: "Eduard",
            position: SIMD3<Float>(0, 0, 0)
        )
        let scene = currentScene ?? BasicScene(
            level: Level(
                name: "Basic Level",
                difficulty: .basic,
                obstacles: [
                    Obstacle(
                        name: "Itembox",
                        shape: .box,
                        position: SIMD3<Float>(0, 0, -0.45),
                        size: SIMD3<Float>(0.6, 0.6, 0.6)
                    )
                ]
            )
        )

        self.currentScene = scene
        self.currentController = currentController ?? JoystickController()
        self.currentRobot = robot

        startMovementLoop()
    }

    deinit {
        movementTimer?.invalidate()
    }

    var level: Level {
        currentScene.level
    }

    func updateInput(_ input: ControlInput) {
        (currentController as? JoystickController)?.updateInput(input)
    }

    private func startMovementLoop() {
        movementTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.applyCurrentInput()
        }
    }

    private func applyCurrentInput() {
        let input = currentController.readInput()
        let candidatePosition = currentRobot.move(input: input, step: moveStep)
        let hasMovementInput = input != .idle

        guard hasMovementInput else {
            isBlocked = false
            collisionMessage = nil
            return
        }

        if canMove(to: candidatePosition) {
            objectWillChange.send()
            currentRobot.position = candidatePosition
            collectItemBoxesIfNeeded(at: candidatePosition)
            currentScene.update()
            isBlocked = false
            collisionMessage = nil
        } else {
            isBlocked = true
            collisionMessage = "You're stuck"
        }
    }

    private func canMove(to candidatePosition: SIMD3<Float>) -> Bool {
        let playerHalfSize = currentRobot.collisionSize / 2
        let playerMin = candidatePosition - playerHalfSize
        let playerMax = candidatePosition + playerHalfSize

        for obstacle in currentScene.level.obstacles {
            guard obstacle.shape != .box else {
                continue
            }

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

        if let canMoveInRealWorld,
           canMoveInRealWorld(currentRobot.position, candidatePosition) == false {
            return false
        }

        return true
    }

    private func collectItemBoxesIfNeeded(at playerPosition: SIMD3<Float>) {
        let collectedIDs = currentScene.level.obstacles.compactMap { obstacle -> UUID? in
            guard obstacle.shape == .box else {
                return nil
            }

            return overlaps(playerPosition: playerPosition, obstacle: obstacle) ? obstacle.id : nil
        }

        guard collectedIDs.isEmpty == false else {
            return
        }

        var level = currentScene.level
        level.obstacles.removeAll { collectedIDs.contains($0.id) }
        currentScene.level = level
        triggerItemBoxFeedback()
    }

    private func overlaps(playerPosition: SIMD3<Float>, obstacle: Obstacle) -> Bool {
        let playerHalfSize = currentRobot.collisionSize / 2
        let playerMin = playerPosition - playerHalfSize
        let playerMax = playerPosition + playerHalfSize

        let obstacleCenter = obstacle.position + SIMD3<Float>(0, obstacle.size.y / 2, 0)
        let obstacleHalfSize = obstacle.size / 2
        let obstacleMin = obstacleCenter - obstacleHalfSize
        let obstacleMax = obstacleCenter + obstacleHalfSize

        let overlapsX = playerMin.x <= obstacleMax.x && playerMax.x >= obstacleMin.x
        let overlapsY = playerMin.y <= obstacleMax.y && playerMax.y >= obstacleMin.y
        let overlapsZ = playerMin.z <= obstacleMax.z && playerMax.z >= obstacleMin.z

        return overlapsX && overlapsY && overlapsZ
    }

    private func triggerItemBoxFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        itemBoxMessage = "Itembox hit"
        itemBoxMessageClearWorkItem?.cancel()

        let clearWorkItem = DispatchWorkItem { [weak self] in
            self?.itemBoxMessage = nil
        }

        itemBoxMessageClearWorkItem = clearWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: clearWorkItem)
    }
}
