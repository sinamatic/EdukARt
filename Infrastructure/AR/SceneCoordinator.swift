//
//  SceneCoordinator.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import ARKit
import RealityKit
import UIKit

final class SceneCoordinator {
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
    
    func makeScene(from game: Game) -> AnchorEntity {
        addPlayer(from: game.currentRobot)
        addObstacles(from: game.currentScene.level.obstacles)
        return anchorEntity
    }
    
    func updateScene(from game: Game, in arView: ARView) {
        if arView.scene.anchors.isEmpty {
            arView.scene.anchors.append(makeScene(from: game))
            return
        }
        
        playerEntity.position = game.currentRobot.position
        syncObstacles(from: game.currentScene.level.obstacles)
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
    
    
    
    
    
    private func addObstacles(from obstacles: [Obstacle]) {
        for obstacle in obstacles {
            guard obstacleEntities[obstacle.id] == nil else {
                continue
            }

            switch obstacle.shape {
            case .box:
                do {
                    let itemBoxEntity = try Entity.load(named: "Itembox")
                    itemBoxEntity.orientation = playerModelPitchCorrection

                    let bounds = itemBoxEntity.visualBounds(relativeTo: itemBoxEntity)
                    
                    let basePosition = obstacle.position + SIMD3<Float>(0, -bounds.min.y, 0)

                    itemBoxEntity.position = basePosition

                    itemBoxEntity.components.set(
                        CollisionComponent(
                            shapes: [
                                .generateBox(size: obstacle.size)
                            ]
                        )
                    )

                    itemBoxEntity.components.set(
                        PhysicsBodyComponent(mode: .static)
                    )

                    anchorEntity.addChild(itemBoxEntity)
                    obstacleEntities[obstacle.id] = itemBoxEntity
                    startFloatingAnimation(for: itemBoxEntity, basePosition: basePosition)
                    startRotationAnimation(for: itemBoxEntity)
                } catch {
                    print("Failed to load Itembox: \(error)")
                }
            }
        }

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
    private let debugAnchor = AnchorEntity(world: .zero)
    private let axisEntity = Entity()
    private var hasAttachedDebugAnchor = false
    private(set) var isDebugEnabled = false

    init() {
        axisEntity.addChild(makeAxisEntity())
        axisEntity.position = SIMD3<Float>(0, 0.02, 0)
        debugAnchor.addChild(axisEntity)
    }

    func configureSession(_ configuration: ARWorldTrackingConfiguration) {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
    }

    func updateDebugState(isEnabled: Bool, in arView: ARView) {
        if hasAttachedDebugAnchor == false {
            arView.scene.anchors.append(debugAnchor)
            hasAttachedDebugAnchor = true
        }

        guard isDebugEnabled != isEnabled else {
            axisEntity.isEnabled = isEnabled
            return
        }

        isDebugEnabled = isEnabled
        axisEntity.isEnabled = isEnabled

        if isEnabled {
            arView.debugOptions.insert(.showWorldOrigin)
            arView.debugOptions.insert(.showSceneUnderstanding)
            arView.debugOptions.insert(.showAnchorGeometry)
        } else {
            arView.debugOptions.remove(.showWorldOrigin)
            arView.debugOptions.remove(.showSceneUnderstanding)
            arView.debugOptions.remove(.showAnchorGeometry)
        }
    }

    private func makeAxisEntity() -> Entity {
        let rootEntity = Entity()
        let axisLength: Float = 0.18
        let axisWidth: Float = 0.004
        let planeSize: Float = 0.16

        let xAxis = ModelEntity(
            mesh: .generateBox(size: [axisLength, axisWidth, axisWidth]),
            materials: [UnlitMaterial(color: .systemRed)]
        )
        xAxis.position = [axisLength / 2, 0, 0]

        let yAxis = ModelEntity(
            mesh: .generateBox(size: [axisWidth, axisLength, axisWidth]),
            materials: [UnlitMaterial(color: .systemGreen)]
        )
        yAxis.position = [0, axisLength / 2, 0]

        let zAxis = ModelEntity(
            mesh: .generateBox(size: [axisWidth, axisWidth, axisLength]),
            materials: [UnlitMaterial(color: .systemBlue)]
        )
        zAxis.position = [0, 0, axisLength / 2]

        let xyPlane = ModelEntity(
            mesh: .generatePlane(width: planeSize, depth: planeSize),
            materials: [UnlitMaterial(color: UIColor.systemYellow.withAlphaComponent(0.15))]
        )
        xyPlane.position = [planeSize / 2, planeSize / 2, 0]

        let xzPlane = ModelEntity(
            mesh: .generatePlane(width: planeSize, depth: planeSize),
            materials: [UnlitMaterial(color: UIColor.systemCyan.withAlphaComponent(0.15))]
        )
        xzPlane.position = [planeSize / 2, 0, planeSize / 2]
        xzPlane.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

        let yzPlane = ModelEntity(
            mesh: .generatePlane(width: planeSize, depth: planeSize),
            materials: [UnlitMaterial(color: UIColor.systemPink.withAlphaComponent(0.15))]
        )
        yzPlane.position = [0, planeSize / 2, planeSize / 2]
        yzPlane.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])

        let origin = ModelEntity(
            mesh: .generateSphere(radius: 0.008),
            materials: [UnlitMaterial(color: .white)]
        )

        rootEntity.addChild(xyPlane)
        rootEntity.addChild(xzPlane)
        rootEntity.addChild(yzPlane)
        rootEntity.addChild(xAxis)
        rootEntity.addChild(yAxis)
        rootEntity.addChild(zAxis)
        rootEntity.addChild(origin)

        return rootEntity
    }
}
