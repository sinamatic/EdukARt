//
//  SceneCoordinator.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import ARKit
import RealityKit
import UIKit

enum RealRobotTrackingConstants {
    static let robotTagName = "tag36h11-2"
    static let tagHeightOffset: Float = 0.10
    static let trackingLossGracePeriod: TimeInterval = 2.5
    static let imageForwardSign: Float = -1
}

final class SceneCoordinator: NSObject, ARSessionDelegate {
    private let anchorEntity = AnchorEntity(
        plane: .horizontal,
        classification: .any,
        minimumBounds: SIMD2<Float>(0.5, 0.5)
    )
    var debugController: SceneDebugController?
    private let playerEntity = Entity()
    private let playerModelPitchCorrection = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
    private var realWorldCollisionShape: ShapeResource?
    private var obstacleEntities: [UUID: Entity] = [:]
    private var collectibleTemplates: [String: Entity] = [:]
    private weak var game: Game?
    private var lastRealRobotDetectionDate = Date.distantPast
    private var realRobotOrientation: simd_quatf?
    private var hasScheduledInitialObstacles = false
    private var hasLoadedInitialObstacles = false
    
    func makeScene(from game: Game) -> AnchorEntity {
        self.game = game
        addPlayer(from: game.currentRobot)
        return anchorEntity
    }
    
    func updateScene(from game: Game, in arView: ARView) {
        if arView.scene.anchors.isEmpty {
            arView.scene.anchors.append(makeScene(from: game))
            return
        }
        
        setPlayerVisibility(isVisible: game.isRealRobotTracked == false)
        playerEntity.position = game.currentRobot.position
        if let realRobotOrientation {
            playerEntity.orientation = realRobotOrientation
        }
        if hasLoadedInitialObstacles {
            syncObstacles(from: game.currentScene.level.obstacles)
        }
    }

    func loadInitialObstacles(from game: Game) {
        scheduleInitialObstaclesIfNeeded(for: game)
    }

    func configureRealRobotTracking(_ configuration: ARWorldTrackingConfiguration) {
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AprilTags", bundle: nil) else {
            return
        }

        let robotReferenceImages = referenceImages.filter { $0.name == RealRobotTrackingConstants.robotTagName }
        guard robotReferenceImages.isEmpty == false else {
            return
        }

        configuration.detectionImages = Set(robotReferenceImages)
        configuration.maximumNumberOfTrackedImages = 1
        configuration.automaticImageScaleEstimationEnabled = false
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let game else {
            return
        }

        scheduleInitialObstaclesIfNeeded(for: game)

        guard let robotAnchor = frame.anchors
            .compactMap({ $0 as? ARImageAnchor })
            .first(where: { imageAnchor in
                imageAnchor.isTracked &&
                imageAnchor.referenceImage.name == RealRobotTrackingConstants.robotTagName
            }) else {
            clearRealRobotTrackingIfNeeded()
            return
        }

        lastRealRobotDetectionDate = Date()

        let robotPose = makeRealRobotPose(from: robotAnchor.transform)
        realRobotOrientation = robotPose.orientation

        Task { @MainActor in
            game.syncRealRobot(
                tagName: robotAnchor.referenceImage.name ?? "AprilTag",
                position: robotPose.position
            )
        }
    }

    private func scheduleInitialObstaclesIfNeeded(for game: Game) {
        guard hasScheduledInitialObstacles == false else {
            return
        }

        hasScheduledInitialObstacles = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self, weak game] in
            guard let self, let game else {
                return
            }

            self.addObstaclesSequentially(Array(game.currentScene.level.obstacles))
        }
    }

    private func addObstaclesSequentially(_ obstacles: [Obstacle], index: Int = 0) {
        guard index < obstacles.count else {
            hasLoadedInitialObstacles = true
            return
        }

        addObstacles(from: [obstacles[index]])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.addObstaclesSequentially(obstacles, index: index + 1)
        }
    }

    private func clearRealRobotTrackingIfNeeded() {
        guard Date().timeIntervalSince(lastRealRobotDetectionDate) > RealRobotTrackingConstants.trackingLossGracePeriod else {
            return
        }

        realRobotOrientation = nil
        Task { @MainActor [weak game] in
            game?.clearRealRobotTracking()
        }
    }

    private func makeRealRobotPose(from tagWorldTransform: simd_float4x4) -> (position: SIMD3<Float>, orientation: simd_quatf) {
        let tagWorldPosition = SIMD3<Float>(
            tagWorldTransform.columns.3.x,
            tagWorldTransform.columns.3.y,
            tagWorldTransform.columns.3.z
        )
        let tagNormal = simd_normalize(
            SIMD3<Float>(
                tagWorldTransform.columns.1.x,
                tagWorldTransform.columns.1.y,
                tagWorldTransform.columns.1.z
            )
        )
        let robotWorldPosition = tagWorldPosition - (tagNormal * RealRobotTrackingConstants.tagHeightOffset)
        var localRobotPosition = anchorEntity.convert(position: robotWorldPosition, from: nil)
        localRobotPosition.y = max(0, localRobotPosition.y)

        let anchorWorldTransform = anchorEntity.transformMatrix(relativeTo: nil)
        let localTagTransform = anchorWorldTransform.inverse * tagWorldTransform
        let imageForward = simd_normalize(
            SIMD3<Float>(
                localTagTransform.columns.2.x,
                0,
                localTagTransform.columns.2.z
            ) * RealRobotTrackingConstants.imageForwardSign
        )

        guard imageForward.x.isFinite, imageForward.z.isFinite, simd_length(imageForward) > 0.001 else {
            return (localRobotPosition, playerEntity.orientation)
        }

        let yaw = atan2(-imageForward.x, -imageForward.z)
        return (localRobotPosition, simd_quatf(angle: yaw, axis: [0, 1, 0]))
    }
    
    
    private func addPlayer(from player: any RobotTarget) {
        guard playerEntity.children.isEmpty else {
            playerEntity.position = player.position
            return
        }
        
        do {
            let chassisEntity = try Entity.load(named: player.chassisModelName)
            chassisEntity.orientation = playerModelPitchCorrection
            
            let frontLeftWheel = try Entity.load(named: player.frontLeftWheelModelName)
            let frontRightWheel = try Entity.load(named: player.frontRightWheelModelName)
            let backLeftWheel = try Entity.load(named: player.backLeftWheelModelName)
            let backRightWheel = try Entity.load(named: player.backRightWheelModelName)
            
            frontLeftWheel.orientation = playerModelPitchCorrection
            frontRightWheel.orientation = playerModelPitchCorrection
            backLeftWheel.orientation = playerModelPitchCorrection
            backRightWheel.orientation = playerModelPitchCorrection
            
            frontLeftWheel.position = SIMD3<Float>(0,0,0)
            frontRightWheel.position = SIMD3<Float>(0,0,0)
            backLeftWheel.position = SIMD3<Float>(0,0,0)
            backRightWheel.position = SIMD3<Float>(0,0,0)
            
            playerEntity.position = player.position
            playerEntity.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            
            playerEntity.addChild(chassisEntity)
            playerEntity.addChild(frontLeftWheel)
            playerEntity.addChild(frontRightWheel)
            playerEntity.addChild(backLeftWheel)
            playerEntity.addChild(backRightWheel)
            
            // collission box around robot
            playerEntity.components.set(
                CollisionComponent(
                    shapes: [
                        .generateBox(size: player.collisionSize)
                    ]
                )
            )
            
            realWorldCollisionShape = .generateBox(size: SIMD3<Float>(player.collisionSize.x, 0.06, player.collisionSize.z))
            
            let bounds = chassisEntity.visualBounds(relativeTo: playerEntity)
            chassisEntity.position.y -= bounds.min.y
            
            anchorEntity.addChild(playerEntity)
        } catch {
            print("Failed to Load Player: \(error)")
        }
    }

    private func setPlayerVisibility(isVisible: Bool) {
        playerEntity.components.set(
            OpacityComponent(opacity: isVisible ? 1 : 0)
        )
    }
    
    
    
    
    
    private func addObstacles(from obstacles: [Obstacle]) {
        for obstacle in obstacles {
            guard obstacleEntities[obstacle.id] == nil else {
                continue
            }

            switch obstacle.shape {
            case .box:
                do {
                    let collectibleEntity = try makeCollectibleEntity(named: obstacle.modelName)
                    collectibleEntity.orientation = playerModelPitchCorrection

                    let bounds = collectibleEntity.visualBounds(relativeTo: collectibleEntity)
                    let basePosition = obstacle.position + SIMD3<Float>(0, -bounds.min.y, 0)

                    collectibleEntity.position = basePosition

                    collectibleEntity.components.set(
                        CollisionComponent(
                            shapes: [
                                .generateBox(size: obstacle.size)
                            ]
                        )
                    )

                    collectibleEntity.components.set(
                        PhysicsBodyComponent(mode: .static)
                    )

                    anchorEntity.addChild(collectibleEntity)
                    obstacleEntities[obstacle.id] = collectibleEntity
                    if obstacle.modelName == "Coin" {
                        startCoinRotationAnimation(for: collectibleEntity, delay: coinAnimationDelay(for: obstacle))
                    } else {
                        startFloatingAnimation(for: collectibleEntity, basePosition: basePosition)
                        startRotationAnimation(for: collectibleEntity)
                    }
                } catch {
                    print("Failed to load \(obstacle.modelName): \(error)")
                }
            }
        }

    }

    private func makeCollectibleEntity(named modelName: String) throws -> Entity {
        if let template = collectibleTemplates[modelName] {
            return template.clone(recursive: true)
        }

        let template = try Entity.load(named: modelName)
        collectibleTemplates[modelName] = template
        return template.clone(recursive: true)
    }

    private func syncObstacles(from obstacles: [Obstacle]) {
        addObstacles(from: obstacles)

        let activeIDs = Set(obstacles.map(\.id))
        let removedIDs = obstacleEntities.keys.filter { activeIDs.contains($0) == false }

        for removedID in removedIDs {
            if let entity = obstacleEntities.removeValue(forKey: removedID) {
                animateRemoval(of: entity)
            }
        }
    }

    private func animateRemoval(of entity: Entity) {
        guard let parent = entity.parent else {
            return
        }

        entity.move(
            to: Transform(
                scale: SIMD3<Float>(repeating: 0.001),
                rotation: entity.orientation,
                translation: entity.position + SIMD3<Float>(0, 0.04, 0)
            ),
            relativeTo: parent,
            duration: 0.2,
            timingFunction: .easeIn
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            entity.removeFromParent()
        }
    }
    private func startFloatingAnimation(for entity: Entity, basePosition: SIMD3<Float>) {
        let upperPosition = basePosition + SIMD3<Float>(0, 0.01, 0)
        let lowerPosition = basePosition - SIMD3<Float>(0, 0.01, 0)

        func animateUp() {
            guard entity.parent != nil else {
                return
            }

            entity.move(
                to: Transform(scale: entity.scale, rotation: entity.orientation, translation: upperPosition),
                relativeTo: entity.parent,
                duration: 1.0,
                timingFunction: .easeInOut
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                animateDown()
            }
        }

        func animateDown() {
            guard entity.parent != nil else {
                return
            }

            entity.move(
                to: Transform(scale: entity.scale, rotation: entity.orientation, translation: lowerPosition),
                relativeTo: entity.parent,
                duration: 1.0,
                timingFunction: .easeInOut
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                animateUp()
            }
        }

        animateUp()
    }
    
    
    private func startRotationAnimation(for entity: Entity) {
        guard entity.parent != nil else {
            return
        }

        let fullRotation = simd_quatf(angle: -.pi * 2, axis: [0, 0, 1])
        let targetTransform = Transform(
            scale: entity.scale,
            rotation: fullRotation * entity.orientation,
            translation: entity.position
        )

        entity.move(
            to: targetTransform,
            relativeTo: entity.parent,
            duration: 12.0,
            timingFunction: .linear
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) {
            self.startRotationAnimation(for: entity)
        }
    }

    private func coinAnimationDelay(for obstacle: Obstacle) -> TimeInterval {
        let distanceOffset = max(0, abs(obstacle.position.z) - 0.65)
        return TimeInterval(distanceOffset * 1.25)
    }

    private func startCoinRotationAnimation(for entity: Entity, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let baseOrientation = entity.orientation
            let flippedOrientation = simd_quatf(angle: .pi, axis: [0, 1, 0]) * baseOrientation

            func rotate(to orientation: simd_quatf, then next: @escaping () -> Void) {
                guard entity.parent != nil else {
                    return
                }

                entity.move(
                    to: Transform(scale: entity.scale, rotation: orientation, translation: entity.position),
                    relativeTo: entity.parent,
                    duration: 7.0,
                    timingFunction: .easeInOut
                )

                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0, execute: next)
            }

            func rotateForward() {
                rotate(to: flippedOrientation, then: rotateBack)
            }

            func rotateBack() {
                rotate(to: baseOrientation, then: rotateForward)
            }

            rotateForward()
        }
    }
    
    
    func canMoveInRealWorld(from currentPosition: SIMD3<Float>, to candidatePosition: SIMD3<Float>, in arView: ARView) -> Bool {
        guard let realWorldCollisionShape else {
            return true
        }
        
        let heightOffset: Float = 0.08
        
        let localFromPosition = currentPosition + SIMD3<Float>(0, heightOffset, 0)
        let localToPosition = candidatePosition + SIMD3<Float>(0, heightOffset, 0)
        
        let worldFromPosition = anchorEntity.convert(position: localFromPosition, to: nil)
        let worldToPosition = anchorEntity.convert(position: localToPosition, to: nil)
        
        let hits = arView.scene.convexCast(
            convexShape: realWorldCollisionShape,
            fromPosition: worldFromPosition,
            fromOrientation: playerEntity.orientation,
            toPosition: worldToPosition,
            toOrientation: playerEntity.orientation,
            query: .nearest,
            mask: .sceneUnderstanding,
            relativeTo: nil
        )
        
        return hits.isEmpty
    }
}

final class SceneDebugController {
    private(set) var isDebugEnabled = false

    init() {}

    func configureSession(_ configuration: ARWorldTrackingConfiguration) {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
    }

    func updateDebugState(isEnabled: Bool, in arView: ARView) {
        guard isDebugEnabled != isEnabled else {
            return
        }

        isDebugEnabled = isEnabled

        if isEnabled {
            arView.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView.debugOptions.remove(.showSceneUnderstanding)
        }
    }
}
private extension Obstacle {
    var modelName: String {
        name
    }
}
