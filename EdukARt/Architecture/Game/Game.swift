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
    @Published var realRobotTagName: String?

    private enum CollectibleLayout {
        static let itemBoxSize = SIMD3<Float>(0.32, 0.32, 0.32)
    }

    let currentScene: any GameScene
    let currentController: any ControlSource
    let currentRobot: any RobotTarget
    let selectedMap: StoredFloorMap?

    private let moveStep: Float = 0.02
    private var movementTimer: Timer?
    private var itemBoxMessageClearWorkItem: DispatchWorkItem?

    var canMoveInRealWorld: ((SIMD3<Float>, SIMD3<Float>) -> Bool)?
    var isRealRobotTracked: Bool {
        realRobotTagName != nil
    }

    init(
        selectedMap: StoredFloorMap? = nil,
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
                obstacles: selectedMap.map(Self.makeCoinGrid(from:)) ?? Self.makeLinearCollectibles(around: robot.position)
            )
        )

        self.currentScene = scene
        self.currentController = currentController ?? JoystickController()
        self.currentRobot = robot
        self.selectedMap = selectedMap

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
        guard isRealRobotTracked == false else {
            isBlocked = false
            collisionMessage = nil
            return
        }

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

    func syncRealRobot(tagName: String, position: SIMD3<Float>) {
        objectWillChange.send()
        realRobotTagName = tagName
        currentRobot.position = position
        collectItemBoxesIfNeeded(at: position)
        currentScene.update()
        isBlocked = false
        collisionMessage = nil
    }

    func clearRealRobotTracking() {
        realRobotTagName = nil
    }

    private func canMove(to candidatePosition: SIMD3<Float>) -> Bool {
        let playerHalfSize = currentRobot.collisionSize / 2
        let playerMin = candidatePosition - playerHalfSize
        let playerMax = candidatePosition + playerHalfSize

        for obstacle in currentScene.level.obstacles {
            guard obstacle.isCollectible == false else {
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
            guard obstacle.isCollectible else {
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

        itemBoxMessage = "+1"
        itemBoxMessageClearWorkItem?.cancel()

        let clearWorkItem = DispatchWorkItem { [weak self] in
            self?.itemBoxMessage = nil
        }

        itemBoxMessageClearWorkItem = clearWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: clearWorkItem)
    }

    nonisolated private static func makeLinearCollectibles(around origin: SIMD3<Float>) -> [Obstacle] {
        [0.65, 0.85, 1.05].map { distance in
            Obstacle(
                name: "Coin",
                shape: .box,
                position: origin + SIMD3<Float>(0, 0, -Float(distance)),
                size: SIMD3<Float>(0.25, 0.25, 0.25)
                
            )
        }
    }

    nonisolated private static func makeCoinGrid(from map: StoredFloorMap) -> [Obstacle] {
        let coinGridSpacing: Float = 0.5
        let maxCoinCount = 80
        var occupiedGridCells = Set<String>()
        var coins: [Obstacle] = []

        for tile in map.floorTiles {
            let gridX = Int((tile.x / coinGridSpacing).rounded())
            let gridZ = Int((tile.z / coinGridSpacing).rounded())
            let key = "\(gridX):\(gridZ)"

            guard occupiedGridCells.insert(key).inserted else {
                continue
            }

            let x = Float(gridX) * coinGridSpacing
            let z = Float(gridZ) * coinGridSpacing
            guard simd_length(SIMD2<Float>(x, z)) > 0.35 else {
                continue
            }

            coins.append(
                Obstacle(
                    name: "Coin",
                    shape: .box,
                    position: SIMD3<Float>(x, tile.y, z),
                    size: SIMD3<Float>(0.25, 0.25, 0.25)
                )
            )

            if coins.count >= maxCoinCount {
                break
            }
        }

        return coins.isEmpty ? makeLinearCollectibles(around: .zero) : coins
    }
}

private extension Obstacle {
    var isCollectible: Bool {
        switch shape {
        case .box:
            return true
        }
    }
}
