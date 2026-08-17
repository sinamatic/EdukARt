//
//  UIARTrackElements.swift
//  EdukARt
//

import Foundation
import RealityKit
import simd

struct UIARTrackElements {
    
    static func draw(
        elements: [MapTrackElement],
        referenceWorldTransform: simd_float4x4,
        in arView: ARView
    ) {
        
        guard elements.isEmpty == false else {
            return
        }
        
        
        let anchor = AnchorEntity(
            world: referenceWorldTransform
        )
        
        anchor.name = "ARTrackElements"
        
        
        for element in elements {
            
            guard let entity = loadEntity(
                for: element.type
            ) else {
                continue
            }
            
            
            entity.name =
                "trackElement_\(element.id.uuidString)"
            
            
            entity.position = SIMD3<Float>(
                element.x,
                element.y,
                -0.05
            )
            
            
            configureOrientation(
                entity,
                for: element.type
            )
            
            
            anchor.addChild(entity)
        }
        
        
        arView.scene.addAnchor(anchor)
    }
    
    
    static func remove(
        elementIDs: Set<UUID>,
        from arView: ARView
    ) {
        
        for id in elementIDs {
            
            let entityName =
                "trackElement_\(id.uuidString)"
            
            
            for anchor in arView.scene.anchors {
                
                if let entity =
                    anchor.findEntity(
                        named: entityName
                    ) {
                    
                    entity.removeFromParent()
                }
            }
        }
    }
    
    
    private static func loadEntity(
        for type: MapTrackElementType
    ) -> Entity? {
        
        switch type {
            
        case .coin:
            
            return try? Entity.load(
                named: "Coin"
            )
            
            
        case .itemBox:
            
            return try? Entity.load(
                named: "Itembox"
            )
        }
    }
    
    
    private static func configureOrientation(
        _ entity: Entity,
        for type: MapTrackElementType
    ) {
        
        switch type {
            
        case .coin:
            
            entity.orientation = simd_quatf(
                angle: .pi / 2,
                axis: SIMD3<Float>(
                    1,
                    0,
                    0
                )
            )
            
            
        case .itemBox:
            
            entity.orientation = simd_quatf(
                angle: .pi / 2,
                axis: SIMD3<Float>(
                    1,
                    0,
                    0
                )
            )
        }
    }
}
