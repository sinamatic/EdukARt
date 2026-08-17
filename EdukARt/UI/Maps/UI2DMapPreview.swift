//
//  UI2DMapPreview.swift
//  EdukARt
//

import SwiftUI

struct UI2DMapPreview: View {
    
    let map: GameMap
    var robotPosition: SIMD3<Float>? = nil
    
    
    var body: some View {
        GeometryReader { geometry in
            
            let transform = MapCoordinateTransform(
                bounds: map.mapBounds,
                size: geometry.size
            )
            
            ZStack {
                
                Color.black.opacity(0.3)
                
                
                // MARK: - Track
                
                if map.trackPoints.count > 1 {
                    
                    Path { path in
                        
                        let first = map.trackPoints[0]
                        
                        path.move(
                            to: transform.screenPoint(
                                x: first.x,
                                y: first.y
                            )
                        )
                        
                        
                        for trackPoint in map.trackPoints.dropFirst() {
                            
                            path.addLine(
                                to: transform.screenPoint(
                                    x: trackPoint.x,
                                    y: trackPoint.y
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
                
                
                // MARK: - AprilTags
                
                ForEach(map.aprilTags) { tag in
                    
                    let point = transform.screenPoint(
                        x: tag.x,
                        y: tag.y
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
                
                
                // MARK: - Robot
                
                if let robotPosition {
                    
                    let point = transform.screenPoint(
                        x: robotPosition.x,
                        y: robotPosition.y
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
    
    
    // MARK: - AprilTag Marker
    
    private var aprilTagMarker: some View {
        Rectangle()
            .fill(.white)
            .overlay(
                Rectangle()
                    .fill(.black)
                    .padding(5)
            )
    }
}
