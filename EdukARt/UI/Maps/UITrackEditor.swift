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
                
                let transform = MapCoordinateTransform(
                    bounds: map.mapBounds,
                    size: geometry.size
                )
                
                ZStack {
                    
                    Color.black
                    
                    
                    // MARK: - AprilTags
                    
                    ForEach(map.aprilTags) { tag in
                        
                        let point = transform.screenPoint(
                            x: tag.x,
                            y: tag.y
                        )
                        
                        VStack(spacing: 2) {
                            
                            Circle()
                                .fill(.green)
                                .frame(
                                    width: 20,
                                    height: 20
                                )
                            
                            Text("#\(tag.id)")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .position(point)
                    }
                    
                    
                    // MARK: - Track
                    
                    if trackPoints.count > 1 {
                        
                        Path { path in
                            
                            let first = trackPoints[0]
                            
                            path.move(
                                to: transform.screenPoint(
                                    x: first.x,
                                    y: first.y
                                )
                            )
                            
                            
                            for point in trackPoints.dropFirst() {
                                
                                path.addLine(
                                    to: transform.screenPoint(
                                        x: point.x,
                                        y: point.y
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
                            
                            let point = transform.mapPoint(
                                from: value.location
                            )
                            
                            addPoint(point)
                        }
                )
            }
            .aspectRatio(1, contentMode: .fit)
            
            
            // MARK: - Buttons
            
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
        
        // Verhindert extrem viele Punkte direkt nebeneinander
        
        if let last = trackPoints.last {
            
            let dx = point.x - last.x
            let dy = point.y - last.y
            
            let distance = sqrt(
                dx * dx +
                dy * dy
            )
            
            // Mindestens 2 cm Abstand
            
            guard distance > 0.02 else {
                return
            }
        }
        
        trackPoints.append(point)
    }
}
