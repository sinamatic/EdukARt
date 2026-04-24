//
//  SceneCoordinator.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import RealityKit
import UIKit

final class SceneCoordinator {
    private let anchorEntity = AnchorEntity(
        plane: .horizontal,
        classification: .any,
        minimumBounds: SIMD2<Float>(0.5, 0.5)
    )
    private let playerEntity = Entity()
    private let playerModelPitchCorrection = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

    func makeScene(from world: GameWorld) -> AnchorEntity {
        addPlayer(from: world.level.player)
        addObstacles(from: world.level.obstacles)
        return anchorEntity
    }

    func updateScene(from world: GameWorld, in arView: ARView) {
        if arView.scene.anchors.isEmpty {
            arView.scene.anchors.append(makeScene(from: world))
            return
        }

        playerEntity.position = world.level.player.position
    }
    

    private func addPlayer(from player: EduardPlayer) {
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
            
            let bounds = chassisEntity.visualBounds(relativeTo: playerEntity)
            chassisEntity.position.y -= bounds.min.y
            
            anchorEntity.addChild(playerEntity)
        } catch {
            print("Failed to Load Player: \(error)")
        }
    }
    
    
    
    

    private func addObstacles(from obstacles: [Obstacle]) {
        for obstacle in obstacles {
            switch obstacle.shape {
            case .box:
                let mesh = MeshResource.generateBox(size: obstacle.size)
                let material = SimpleMaterial(color: .gray, roughness: 0.4, isMetallic: false)
                let boxEntity = ModelEntity(mesh: mesh, materials: [material])
                boxEntity.position = obstacle.position + SIMD3<Float>(0, obstacle.size.y / 2, 0)
                anchorEntity.addChild(boxEntity)
            }
        }
    }
}
