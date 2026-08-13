//  MapLocalization.swift
//  EdukARt
//

import simd

struct MapLocalization {
    
    let referenceWorldTransform: simd_float4x4
    
    
    func mapPosition(
        from worldTransform: simd_float4x4
    ) -> SIMD3<Float> {
        
        let mapTransform =
            referenceWorldTransform.inverse * worldTransform
        
        return SIMD3<Float>(
            mapTransform.columns.3.x,
            mapTransform.columns.3.y,
            mapTransform.columns.3.z
        )
    }
    
    
    func worldPosition(
        from mapTag: MapAprilTag
    ) -> SIMD3<Float> {
        
        var mapTransform = matrix_identity_float4x4
        
        mapTransform.columns.3 = SIMD4<Float>(
            mapTag.x,
            mapTag.y,
            mapTag.z,
            1
        )
        
        let worldTransform =
            referenceWorldTransform * mapTransform
        
        return SIMD3<Float>(
            worldTransform.columns.3.x,
            worldTransform.columns.3.y,
            worldTransform.columns.3.z
        )
    }
}
