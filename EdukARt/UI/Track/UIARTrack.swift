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
        
        let trackAnchor = AnchorEntity(
            world: referenceWorldTransform
        )
        
        trackAnchor.name = "ARTrack"
        
        
        if map.trackPoints.count > 1 {
            for index in 0..<(map.trackPoints.count - 1) {
                
                let start = map.trackPoints[index]
                let end = map.trackPoints[index + 1]
                
//                addDashes(
//                    from: start,
//                    to: end,
//                    to: trackAnchor
//                )
                
                addLineSegment(
                    from: start,
                    to: end,
                    to: trackAnchor
                )
            }
        }
        
        
        for element in map.trackElements {
            addTrackElement(
                element,
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
//    
//    
//    private static func addDashes(
//        from start: MapPoint,
//        to end: MapPoint,
//        to anchor: AnchorEntity
//    ) {
//        
//        let startX = start.x
//        let startY = start.y
//        
//        let endX = end.x
//        let endY = end.y
//        
//        
//        let deltaX = endX - startX
//        let deltaY = endY - startY
//        
//        
//        let segmentLength = sqrt(
//            deltaX * deltaX +
//            deltaY * deltaY
//        )
//        
//        
//        guard segmentLength > 0 else {
//            return
//        }
//        
//        
//        let dashLength: Float = 0.15
//        let gapLength: Float = 0.10
//        
//        let dashWidth: Float = 0.03
//        let dashHeight: Float = 0.005
//        
//        let stepLength =
//            dashLength + gapLength
//        
//        
//        let directionX =
//            deltaX / segmentLength
//        
//        let directionY =
//            deltaY / segmentLength
//        
//        
//        var distance: Float = 0
//        
//        
//        while distance < segmentLength {
//            
//            let remainingDistance =
//                segmentLength - distance
//            
//            let currentDashLength =
//                min(
//                    dashLength,
//                    remainingDistance
//                )
//            
//            
//            let centerDistance =
//                distance + currentDashLength / 2
//            
//            
//            let centerX =
//                startX +
//                directionX * centerDistance
//            
//            let centerY =
//                startY +
//                directionY * centerDistance
//            
//            
//            let dash = makeDash(
//                length: currentDashLength,
//                width: dashWidth,
//                height: dashHeight
//            )
//            
//            
//            dash.position = SIMD3<Float>(
//                centerX,
//                centerY,
//                -0.01
//            )
//            
//            
//            let angle =
//                atan2(deltaY, deltaX)
//            
//            
//            dash.orientation = simd_quatf(
//                angle: angle,
//                axis: SIMD3<Float>(0, 0, 1)
//            )
//            
//            
//            anchor.addChild(dash)
//            
//            
//            distance += stepLength
//        }
//    }
    
    private static func addLineSegment(
        from start: MapPoint,
        to end: MapPoint,
        to anchor: AnchorEntity
    ) {
        
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        
        let length = sqrt(
            deltaX * deltaX +
            deltaY * deltaY
        )
        
        guard length > 0 else {
            return
        }
        
        
        let centerX =
            (start.x + end.x) / 2
        
        let centerY =
            (start.y + end.y) / 2
        
        
        let lineWidth: Float = 0.03
        let lineHeight: Float = 0.005
        
        
        let mesh = MeshResource.generateBox(
            width: length,
            height: lineWidth,
            depth: lineHeight
        )
        
        
        let material = SimpleMaterial(
            color: .white,
            isMetallic: false
        )
        
        
        let line = ModelEntity(
            mesh: mesh,
            materials: [material]
        )
        
        
        line.position = SIMD3<Float>(
            centerX,
            centerY,
            -0.005
        )
        
        
        let angle = atan2(
            deltaY,
            deltaX
        )
        
        
        line.orientation = simd_quatf(
            angle: angle,
            axis: SIMD3<Float>(0, 0, 1)
        )
        
        
        anchor.addChild(line)
    }
    
    
    private static func addTrackElement(
        _ element: MapTrackElement,
        to anchor: AnchorEntity
    ) {
        
        let entity =
            makeTrackElementEntity(
                for: element.type
            )
        
        
        entity.position = SIMD3<Float>(
            element.x,
            element.y,
            -0.04
        )
        
        
        anchor.addChild(entity)
    }
    
    
    private static func makeTrackElementEntity(
        for type: MapTrackElementType
    ) -> Entity {
        
        switch type {
        case .coin:
            if let coin = try? ModelEntity.loadModel(
                named: "Coin"
            ) {
                coin.scale = SIMD3<Float>(
                    repeating: 0.08
                )
                
                return coin
            }
            
            let mesh = MeshResource.generateSphere(
                radius: 0.04
            )
            
            let material = SimpleMaterial(
                color: .yellow,
                isMetallic: true
            )
            
            return ModelEntity(
                mesh: mesh,
                materials: [material]
            )
            
        case .itemBox:
            if let itemBox = try? ModelEntity.loadModel(
                named: "Itembox"
            ) {
                itemBox.scale = SIMD3<Float>(
                    repeating: 0.08
                )
                
                return itemBox
            }
            
            let mesh = MeshResource.generateBox(
                size: 0.08
            )
            
            let material = SimpleMaterial(
                color: .systemPink,
                isMetallic: false
            )
            
            return ModelEntity(
                mesh: mesh,
                materials: [material]
            )
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
