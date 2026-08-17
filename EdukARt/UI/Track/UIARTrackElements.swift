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
            
            
            entity.position = SIMD3<Float>(
                element.x,
                element.y,
                -0.05
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
}
