//
//  TrackCollisionController.swift
//  EdukARt
//

import Foundation
import simd

final class TrackCollisionController {
    
    private let collisionDistance: Float = 0.20
    
    private var triggeredElements: Set<UUID> = []
    
    
    func checkCollisions(
        robotPosition: SIMD3<Float>,
        elements: [MapTrackElement],
        onCollision: (MapTrackElement) -> Void
    ) {
        
        for element in elements {
            
            // Bereits eingesammelt / ausgelöst
            guard triggeredElements.contains(element.id) == false else {
                continue
            }
            
            
            let dx =
                robotPosition.x - element.x
            
            let dy =
                robotPosition.y - element.y
            
            
            let distance = sqrt(
                dx * dx +
                dy * dy
            )
            
            
            guard distance <= collisionDistance else {
                continue
            }
            
            
            triggeredElements.insert(
                element.id
            )
            
            onCollision(element)
        }
    }
    
    
    func reset() {
        triggeredElements.removeAll()
    }
}
