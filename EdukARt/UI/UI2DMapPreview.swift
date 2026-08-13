//
//  UIMapPreview.swift
//  EdukARt
//

import SwiftUI

struct UI2DMapPreview: View {
    
    let map: GameMap
    
    var body: some View {
        GeometryReader { geometry in
            
            let points = map.aprilTags.map { tag in
                CGPoint(
                    x: CGFloat(tag.x),
                    y: CGFloat(tag.y)
                )
            }
            
            let bounds = mapBounds(points)
            let scale = mapScale(
                bounds: bounds,
                size: geometry.size
            )
            
            
            ZStack {
                
                Color.black.opacity(0.85)
                
                
                ForEach(map.aprilTags) { tag in
                    
                    let point = screenPoint(
                        for: tag,
                        bounds: bounds,
                        scale: scale,
                        size: geometry.size
                    )
                    
                    
                    VStack(spacing: 4) {
                        
                        Circle()
                            .fill(.green)
                            .frame(width: 18, height: 18)
                        
                        Text("#\(tag.id)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .position(point)
                }
            }
            .clipShape(
                RoundedRectangle(cornerRadius: 12)
            )
        }
    }
    
    
    private func mapBounds(
        _ points: [CGPoint]
    ) -> CGRect {
        
        guard let first = points.first else {
            return .zero
        }
        
        
        var minX = first.x
        var maxX = first.x
        
        var minY = first.y
        var maxY = first.y
        
        
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        
        
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
    
    
    private func mapScale(
        bounds: CGRect,
        size: CGSize
    ) -> CGFloat {
        
        let padding: CGFloat = 40
        
        let availableWidth =
            size.width - padding * 2
        
        let availableHeight =
            size.height - padding * 2
        
        
        let xScale =
            availableWidth / max(bounds.width, 0.01)
        
        let yScale =
            availableHeight / max(bounds.height, 0.01)
        
        
        return min(xScale, yScale)
    }
    
    
    private func screenPoint(
        for tag: MapAprilTag,
        bounds: CGRect,
        scale: CGFloat,
        size: CGSize
    ) -> CGPoint {
        
        let padding: CGFloat = 40
        
        
        let x =
            (CGFloat(tag.x) - bounds.minX) * scale
            + padding
        
        let y =
            (CGFloat(tag.y) - bounds.minY) * scale
            + padding
        
        
        return CGPoint(
            x: x,
            y: y
        )
    }
}
