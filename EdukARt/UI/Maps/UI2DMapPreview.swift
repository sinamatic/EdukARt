//
//  UIMapPreview.swift
//  EdukARt
//

import SwiftUI

struct UI2DMapPreview: View {
    
    let map: GameMap
    var robotPosition: SIMD3<Float>? = nil
    
    
    var body: some View {
        GeometryReader { geometry in
            
            let points = allPoints
            let bounds = mapBounds(points)
            let scale = mapScale(
                bounds: bounds,
                size: geometry.size
            )
            
            ZStack {
                
                Color.black.opacity(0.3)
                
                if map.trackPoints.count > 1 {
                    
                    Path { path in
                        
                        let first = map.trackPoints[0]
                        
                        path.move(
                            to: screenPoint(
                                x: first.x,
                                y: first.y,
                                bounds: bounds,
                                scale: scale
                            )
                        )
                        
                        
                        for trackPoint in map.trackPoints.dropFirst() {
                            
                            path.addLine(
                                to: screenPoint(
                                    x: trackPoint.x,
                                    y: trackPoint.y,
                                    bounds: bounds,
                                    scale: scale
                                )
                            )
                        }
                    }
                    .stroke(
                        .yellow,
                        style: StrokeStyle(
                            lineWidth: 8,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
                
                
                // Map AprilTags
                ForEach(map.aprilTags) { tag in
                    
                    let point = screenPoint(
                        x: tag.x,
                        y: tag.y,
                        bounds: bounds,
                        scale: scale
                    )
                    
                    VStack(spacing: 4) {
                        
                        aprilTagMarker
                            .frame(
                                width: 18,
                                height: 18
                            )
                        
                        Text("#\(tag.id)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .position(point)
                }
                
                
                // Robot
                if let robotPosition {
                    
                    let point = screenPoint(
                        x: robotPosition.x,
                        y: robotPosition.y,
                        bounds: bounds,
                        scale: scale
                    )
                    
                    VStack(spacing: 4) {
                        
                        Rectangle()
                            .fill(.blue)
                            .frame(
                                width: 22,
                                height: 22
                            )
                        
                        Text("#0")
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
    
    
    private var aprilTagMarker: some View {
        Rectangle()
            .fill(.white)
            .overlay(
                Rectangle()
                    .fill(.black)
                    .padding(5)
            )
    }
    
    
    // MARK: - Points
    
    private var allPoints: [CGPoint] {
        
        var points = map.aprilTags.map { tag in
            CGPoint(
                x: CGFloat(tag.x),
                y: CGFloat(tag.y)
            )
        }
        
        
        if let robotPosition {
            points.append(
                CGPoint(
                    x: CGFloat(robotPosition.x),
                    y: CGFloat(robotPosition.y)
                )
            )
        }
        
        
        return points
    }
    
    
    // MARK: - Bounds
    
    private func mapBounds(
        _ points: [CGPoint]
    ) -> CGRect {
        
        guard let first = points.first else {
            return CGRect(
                x: 0,
                y: 0,
                width: 1,
                height: 1
            )
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
            width: max(maxX - minX, 0.01),
            height: max(maxY - minY, 0.01)
        )
    }
    
    
    // MARK: - Scale
    
    private func mapScale(
        bounds: CGRect,
        size: CGSize
    ) -> CGFloat {
        
        let padding: CGFloat = 40
        
        let availableWidth =
            max(size.width - padding * 2, 1)
        
        let availableHeight =
            max(size.height - padding * 2, 1)
        
        
        let scaleX =
            availableWidth / bounds.width
        
        let scaleY =
            availableHeight / bounds.height
        
        
        return min(scaleX, scaleY)
    }
    
    
    // MARK: - Screen Position
    
    private func screenPoint(
        x: Float,
        y: Float,
        bounds: CGRect,
        scale: CGFloat
    ) -> CGPoint {
        
        let padding: CGFloat = 40
        
        
        return CGPoint(
            x:
                (CGFloat(x) - bounds.minX)
                * scale
                + padding,
            
            y:
                (CGFloat(y) - bounds.minY)
                * scale
                + padding
        )
    }
}
