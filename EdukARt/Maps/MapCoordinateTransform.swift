//
//  MapCoordinateTransform.swift
//  EdukARt
//

import SwiftUI


struct MapBounds {
    
    let minX: Float
    let maxX: Float
    
    let minY: Float
    let maxY: Float
    
    
    var width: Float {
        maxX - minX
    }
    
    var height: Float {
        maxY - minY
    }
}


struct MapCoordinateTransform {
    
    let bounds: MapBounds
    let size: CGSize
    
    
    // MARK: - Scale
    
    private var scale: CGFloat {
        
        let scaleX =
            size.width / CGFloat(bounds.width)
        
        let scaleY =
            size.height / CGFloat(bounds.height)
        
        return min(scaleX, scaleY)
    }
    
    
    // MARK: - Map Size On Screen
    
    private var mapScreenWidth: CGFloat {
        CGFloat(bounds.width) * scale
    }
    
    private var mapScreenHeight: CGFloat {
        CGFloat(bounds.height) * scale
    }
    
    
    // MARK: - Centering
    
    private var offsetX: CGFloat {
        (size.width - mapScreenWidth) / 2
    }
    
    private var offsetY: CGFloat {
        (size.height - mapScreenHeight) / 2
    }
    
    
    // MARK: - Map -> Screen
    
    func screenPoint(
        x: Float,
        y: Float
    ) -> CGPoint {
        
        let mapX =
            CGFloat(x - bounds.minX)
        
        let mapY =
            CGFloat(y - bounds.minY)
        
        
        return CGPoint(
            x: offsetX + mapX * scale,
            y: offsetY + mapY * scale
        )
    }
    
    
    // MARK: - Screen -> Map
    
    func mapPoint(
        from screenPoint: CGPoint
    ) -> MapPoint {
        
        let x =
            Float(
                (screenPoint.x - offsetX) / scale
            ) + bounds.minX
        
        let y =
            Float(
                (screenPoint.y - offsetY) / scale
            ) + bounds.minY
        
        
        return MapPoint(
            x: x,
            y: y
        )
    }
}


// MARK: - Map Bounds

extension GameMap {
    
    var mapBounds: MapBounds {
        
        let xs = aprilTags.map(\.x)
        let ys = aprilTags.map(\.y)
        
        
        guard
            let minX = xs.min(),
            let maxX = xs.max(),
            let minY = ys.min(),
            let maxY = ys.max()
        else {
            return MapBounds(
                minX: -1,
                maxX: 1,
                minY: -1,
                maxY: 1
            )
        }
        
        
        let padding: Float = 0.3
        
        
        return MapBounds(
            minX: minX - padding,
            maxX: maxX + padding,
            minY: minY - padding,
            maxY: maxY + padding
        )
    }
}
