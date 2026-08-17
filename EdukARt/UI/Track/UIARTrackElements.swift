//
//  UIARTrackElements.swift
//  EdukARt
//

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
            
            
            configure(
                entity,
                for: element.type,
                at: element
            )
            
            
            anchor.addChild(entity)
        }
        
        
        arView.scene.addAnchor(anchor)
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
    
    private static func configure(
        _ entity: Entity,
        for type: MapTrackElementType,
        at element: MapTrackElement
    ) {
        
        entity.position = SIMD3<Float>(
            element.x,
            element.y,
            -0.05
        )
        
        
        switch type {
            
        case .coin:
            
            entity.orientation = simd_quatf(
                angle: .pi / 2,
                axis: SIMD3<Float>(1, 0, 0)
            )
            
            
        case .itemBox:
            
            entity.orientation = simd_quatf(
                angle: .pi / 2,
                axis: SIMD3<Float>(1, 0, 0)
            )
        }
    }
}
