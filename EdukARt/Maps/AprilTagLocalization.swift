//
//  AprilTagLocalization.swift
//  EdukARt
//

import Foundation
import simd

struct AprilTagLocalization {
    
    let referenceWorldTransform: simd_float4x4
    
    
    // MARK: - World -> Reference
    
    func relativeTransform(
        from worldTransform: simd_float4x4
    ) -> simd_float4x4 {
        
        referenceWorldTransform.inverse *
        worldTransform
    }
    
    
    func relativePosition(
        from worldTransform: simd_float4x4
    ) -> SIMD3<Float> {
        
        let transform =
            relativeTransform(
                from: worldTransform
            )
        
        return SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }
    
    
    // MARK: - Reference -> World
    
    func worldTransform(
        from relativeTransform: simd_float4x4
    ) -> simd_float4x4 {
        
        referenceWorldTransform *
        relativeTransform
    }
}
