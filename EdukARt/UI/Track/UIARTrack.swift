//
//  UIARTrack.swift
//  EdukARt
//

import RealityKit
import SwiftUI
import simd

struct UIARTrack {
    
    static func draw(
        map: GameMap,
        referenceWorldTransform: simd_float4x4,
        in arView: ARView
    ) {
        
        remove(from: arView)
        
        guard map.trackPoints.count > 1 else {
            return
        }
        
        
        let trackAnchor = AnchorEntity(
            world: referenceWorldTransform
        )
        
        trackAnchor.name = "ARTrack"
        
        
        for index in 0..<(map.trackPoints.count - 1) {
            
            let start = map.trackPoints[index]
            let end = map.trackPoints[index + 1]
            
            addDashes(
                from: start,
                to: end,
                to: trackAnchor
            )
        }
        
        
        arView.scene.addAnchor(trackAnchor)
    }
    
    
    static func remove(
        from arView: ARView
    ) {
        
        let trackAnchors = arView.scene.anchors.filter {
            $0.name == "ARTrack"
        }
        
        for anchor in trackAnchors {
            arView.scene.removeAnchor(anchor)
        }
    }
    
    
    private static func addDashes(
        from start: MapPoint,
        to end: MapPoint,
        to anchor: AnchorEntity
    ) {
        
        let startX = start.x
        let startY = start.y
        
        let endX = end.x
        let endY = end.y
        
        
        let deltaX = endX - startX
        let deltaY = endY - startY
        
        
        let segmentLength = sqrt(
            deltaX * deltaX +
            deltaY * deltaY
        )
        
        
        guard segmentLength > 0 else {
            return
        }
        
        
        let dashLength: Float = 0.15
        let gapLength: Float = 0.10
        
        let dashWidth: Float = 0.03
        let dashHeight: Float = 0.005
        
        let stepLength =
            dashLength + gapLength
        
        
        let directionX =
            deltaX / segmentLength
        
        let directionY =
            deltaY / segmentLength
        
        
        var distance: Float = 0
        
        
        while distance < segmentLength {
            
            let remainingDistance =
                segmentLength - distance
            
            let currentDashLength =
                min(
                    dashLength,
                    remainingDistance
                )
            
            
            let centerDistance =
                distance + currentDashLength / 2
            
            
            let centerX =
                startX +
                directionX * centerDistance
            
            let centerY =
                startY +
                directionY * centerDistance
            
            
            let dash = makeDash(
                length: currentDashLength,
                width: dashWidth,
                height: dashHeight
            )
            
            
            dash.position = SIMD3<Float>(
                centerX,
                centerY,
                -0.01
            )
            
            
            let angle =
                atan2(deltaY, deltaX)
            
            
            dash.orientation = simd_quatf(
                angle: angle,
                axis: SIMD3<Float>(0, 0, 1)
            )
            
            
            anchor.addChild(dash)
            
            
            distance += stepLength
        }
    }
    
    
    private static func makeDash(
        length: Float,
        width: Float,
        height: Float
    ) -> ModelEntity {
        
        let mesh = MeshResource.generateBox(
            width: length,
            height: width,
            depth: height
        )
        
        
        let material =
            SimpleMaterial(
                color: .white,
                isMetallic: false
            )
        
        
        return ModelEntity(
            mesh: mesh,
            materials: [material]
        )
    }
}
