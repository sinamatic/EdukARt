//
//  UITrackEditor.swift
//  EdukARt
//

import SwiftUI

struct UITrackEditor: View {
    
    let map: GameMap
    @Binding var trackPoints: [MapPoint]
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            
            Text("Draw Track")
                .font(.headline)
            
            
            GeometryReader { geometry in
                
                let bounds = mapBounds
                
                ZStack {
                    
                    Color.black
                    
                    
                    // AprilTags
                    ForEach(map.aprilTags) { tag in
                        
                        let point = screenPoint(
                            x: tag.x,
                            y: tag.y,
                            size: geometry.size,
                            bounds: bounds
                        )
                        
                        VStack(spacing: 2) {
                            
                            Circle()
                                .fill(.green)
                                .frame(width: 20, height: 20)
                            
                            Text("#\(tag.id)")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .position(point)
                    }
                    
                    
                    // Rennstrecke
                    if trackPoints.count > 1 {
                        
                        Path { path in
                            
                            let first = trackPoints[0]
                            
                            path.move(
                                to: screenPoint(
                                    x: first.x,
                                    y: first.y,
                                    size: geometry.size,
                                    bounds: bounds
                                )
                            )
                            
                            
                            for point in trackPoints.dropFirst() {
                                
                                path.addLine(
                                    to: screenPoint(
                                        x: point.x,
                                        y: point.y,
                                        size: geometry.size,
                                        bounds: bounds
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
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            
                            let mapPoint = mapPoint(
                                from: value.location,
                                size: geometry.size,
                                bounds: bounds
                            )
                            
                            addPoint(mapPoint)
                        }
                )
            }
            .aspectRatio(1, contentMode: .fit)
            
            
            HStack {
                
                Button("Undo") {
                    if trackPoints.isEmpty == false {
                        trackPoints.removeLast()
                    }
                }
                
                Spacer()
                
                Button("Clear") {
                    trackPoints.removeAll()
                }
                
                Spacer()
                
                Button("Save Map") {
                    onSave()
                }
            }
            
            
            
            Text("\(trackPoints.count) track points")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()

    }
    
    
    // MARK: - Add Point
    
    private func addPoint(
        _ point: MapPoint
    ) {
        
        // verhindert extrem viele Punkte direkt nebeneinander
        
        if let last = trackPoints.last {
            
            let dx = point.x - last.x
            let dy = point.y - last.y
            
            let distance = sqrt(
                dx * dx +
                dy * dy
            )
            
            // mindestens 2 cm Abstand
            guard distance > 0.02 else {
                return
            }
        }
        
        trackPoints.append(point)
    }
    
    
    // MARK: - Screen -> Map
    
    private func mapPoint(
        from screenPoint: CGPoint,
        size: CGSize,
        bounds: MapBounds
    ) -> MapPoint {
        
        let normalizedX =
            Float(screenPoint.x / size.width)
        
        let normalizedY =
            Float(screenPoint.y / size.height)
        
        
        let x =
            bounds.minX +
            normalizedX * (bounds.maxX - bounds.minX)
        
        let y =
            bounds.minY +
            normalizedY * (bounds.maxY - bounds.minY)
        
        
        return MapPoint(
            x: x,
            y: y
        )
    }
    
    
    // MARK: - Map -> Screen
    
    private func screenPoint(
        x: Float,
        y: Float,
        size: CGSize,
        bounds: MapBounds
    ) -> CGPoint {
        
        let normalizedX =
            (x - bounds.minX) /
            (bounds.maxX - bounds.minX)
        
        let normalizedY =
            (y - bounds.minY) /
            (bounds.maxY - bounds.minY)
        
        
        return CGPoint(
            x: CGFloat(normalizedX) * size.width,
            y: CGFloat(normalizedY) * size.height
        )
    }
    
    
    // MARK: - Bounds
    
    private var mapBounds: MapBounds {
        
        let xs = map.aprilTags.map(\.x)
        let ys = map.aprilTags.map(\.y)
        
        
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


// MARK: - Helper

private struct MapBounds {
    
    let minX: Float
    let maxX: Float
    
    let minY: Float
    let maxY: Float
}
