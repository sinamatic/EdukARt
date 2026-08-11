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
    enum RobotMode {
        case simulation
        case real
    }

    enum SpeedMode: String, CaseIterable, Identifiable {
        case slow = "Langsam"
        case normal = "Normal"
        case fast = "Schnell"

        var id: String { rawValue }

        var metersPerSecond: Float {
            let normalSpeed: Float = 0.1 * .pi * 1.5

            switch self {
            case .slow:
                return normalSpeed * 0.5
            case .normal:
                return normalSpeed
            case .fast:
                return normalSpeed * 1.25
            }
        }

        var speedScale: Float {
            switch self {
            case .slow:
                return 0.5
            case .normal:
                return 1
            case .fast:
                return 1.25
            }
        }
    }

    @Published var collisionMessage: String?
    @Published var itemBoxMessage: String?
    @Published var isBlocked = false
    @Published var realRobotTagName: String?
    @Published var mapOriginMessage: String?
    @Published var isWaitingForMapOrigin = false
    @Published var isChoosingRobotMode = false
    @Published var isWaitingForRealRobot = false
    @Published var robotMode: RobotMode?
    @Published var speedMode: SpeedMode = .normal
    @Published var robotYaw: Float = 0

    private enum CollectibleLayout {
        static let itemBoxSize = SIMD3<Float>(0.32, 0.32, 0.32)
    }

    let currentRobot: EduardRobot
    let selectedMap: StoredFloorMap?
    private(set) var obstacles: [Obstacle]

    private let movementTicksPerSecond: Float = 60
    private let normalRotationRadiansPerSecond: Float = .pi / 2
    private var movementInput = SIMD2<Float>.zero
    private var rotationInput: Float = 0
    private var movementTimer: Timer?
    private var itemBoxMessageClearWorkItem: DispatchWorkItem?

    var canMoveInRealWorld: ((SIMD3<Float>, SIMD3<Float>) -> Bool)?
    var isRealRobotTracked: Bool {
        realRobotTagName != nil
    }

    init(
        selectedMap: StoredFloorMap? = nil,
        currentRobot: EduardRobot? = nil
    ) {
        let robot = currentRobot ?? EduardRobot(
            name: "Eduard",
            position: SIMD3<Float>(0, 0, 0)
        )

        self.currentRobot = robot
        self.selectedMap = selectedMap
        self.obstacles = selectedMap.map(Self.makeCoinGrid(from:)) ?? Self.makeLinearCollectibles(around: robot.position)
        if let selectedMap, selectedMap.referenceTagName != nil {
            isWaitingForMapOrigin = true
            mapOriginMessage = "Scanne AprilTag \(selectedMap.displayReferenceTagNumber), um die Karte auszurichten."
        } else {
            robotMode = .simulation
        }

        startMovementLoop()
    }

    deinit {
        movementTimer?.invalidate()
    }

    func updateInput(_ input: SIMD2<Float>) {
        movementInput = input
    }

    func updateRotationInput(_ input: Float) {
        rotationInput = input
    }

    private func startMovementLoop() {
        movementTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.applyCurrentInput()
        }
    }

    private func applyCurrentInput() {
        guard isChoosingRobotMode == false,
              isWaitingForRealRobot == false,
              isRealRobotTracked == false else {
            isBlocked = false
            collisionMessage = nil
            return
        }

        let rotationStep = rotationInput * normalRotationRadiansPerSecond * speedMode.speedScale / movementTicksPerSecond
        if abs(rotationStep) > 0.0001 {
            objectWillChange.send()
            robotYaw += rotationStep
        }

        let candidatePosition = makeMovementCandidate(
            from: currentRobot.position,
            input: movementInput,
            step: speedMode.metersPerSecond / movementTicksPerSecond
        )

        guard movementInput != .zero else {
            isBlocked = false
            collisionMessage = nil
            return
        }

        if canMove(to: candidatePosition) {
            objectWillChange.send()
            currentRobot.position = candidatePosition
            collectItemBoxesIfNeeded(at: candidatePosition)
            isBlocked = false
            collisionMessage = nil
        } else {
            isBlocked = true
            collisionMessage = "You're stuck"
        }
    }

    private func makeMovementCandidate(from position: SIMD3<Float>, input: SIMD2<Float>, step: Float) -> SIMD3<Float> {
        var localDelta = SIMD3<Float>(0, 0, 0)

        if input.y < -0.5 {
            localDelta.z -= step
        }

        if input.y > 0.5 {
            localDelta.z += step
        }

        if input.x < -0.5 {
            localDelta.x -= step
        }

        if input.x > 0.5 {
            localDelta.x += step
        }

        let yawRotation = simd_quatf(angle: robotYaw, axis: [0, 1, 0])
        return position + yawRotation.act(localDelta)
    }

    func syncRealRobot(tagName: String, position: SIMD3<Float>) {
        objectWillChange.send()
        robotMode = .real
        isWaitingForRealRobot = false
        isChoosingRobotMode = false
        mapOriginMessage = nil
        realRobotTagName = tagName
        currentRobot.position = position
        collectItemBoxesIfNeeded(at: position)
        isBlocked = false
        collisionMessage = nil
    }

    func clearRealRobotTracking() {
        realRobotTagName = nil
    }

    func markMapOriginAligned() {
        isWaitingForMapOrigin = false
        mapOriginMessage = nil
        isChoosingRobotMode = true
    }

    func selectSimulationRobot() {
        robotMode = .simulation
        isChoosingRobotMode = false
        isWaitingForRealRobot = false
        realRobotTagName = nil
    }

    func selectRealRobot() {
        robotMode = .real
        isChoosingRobotMode = false
        isWaitingForRealRobot = true
        realRobotTagName = nil
        mapOriginMessage = "Scanne AprilTag #1 am echten Roboter."
    }

    private func canMove(to candidatePosition: SIMD3<Float>) -> Bool {
        let playerHalfSize = currentRobot.collisionSize / 2
        let playerMin = candidatePosition - playerHalfSize
        let playerMax = candidatePosition + playerHalfSize

        for obstacle in obstacles {
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
        let collectedIDs = obstacles.compactMap { obstacle -> UUID? in
            guard obstacle.isCollectible else {
                return nil
            }

            return overlaps(playerPosition: playerPosition, obstacle: obstacle) ? obstacle.id : nil
        }

        guard collectedIDs.isEmpty == false else {
            return
        }

        obstacles.removeAll { collectedIDs.contains($0.id) }
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
        let coinGridSpacing: Float = 0.75
        let maxCoinCount = 36
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
