//
//  UITrackEditor.swift
//  EdukARt
//

import SwiftUI

struct UITrackEditor: View {
    
    let map: GameMap
    
    @Binding var trackPoints: [MapPoint]
    @Binding var trackElements: [MapTrackElement]
    
    let onSave: () -> Void
    
    
    @State private var editorMode: EditorMode = .track
    
    
    private enum EditorMode: String, CaseIterable, Identifiable {
        
        case track = "Track"
        case coin = "Coin"
        case itemBox = "Itembox"
        
        var id: String {
            rawValue
        }
    }
    
    
    var body: some View {
        VStack(spacing: 16) {
            
            Text("Edit Track")
                .font(.headline)
            
            
            // MARK: - Editor Mode
            
            Picker(
                "Editor Mode",
                selection: $editorMode
            ) {
                
                ForEach(EditorMode.allCases) { mode in
                    Text(mode.rawValue)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            
            // MARK: - Map
            
            GeometryReader { geometry in
                
                let transform = MapCoordinateTransform(
                    bounds: map.mapBounds,
                    size: geometry.size
                )
                
                
                ZStack {
                    
                    Color.black
                    
                    
                    // MARK: Track
                    
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
                    
                    
                    // MARK: Track Elements
                    
                    ForEach(trackElements) { element in
                        
                        let point = transform.screenPoint(
                            x: element.x,
                            y: element.y
                        )
                        
                        
                        Circle()
                            .fill(
                                element.type == .coin
                                ? Color.yellow
                                : Color.pink
                            )
                            .frame(
                                width: 18,
                                height: 18
                            )
                            .position(point)
                    }
                    
                    
                    // MARK: AprilTags
                    
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
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            
                            if editorMode == .track {
                                
                                let point = transform.mapPoint(
                                    from: value.location
                                )
                                
                                addTrackPoint(point)
                            }
                        }
                        .onEnded { value in
                            
                            if editorMode != .track {
                                
                                let point = transform.mapPoint(
                                    from: value.location
                                )
                                
                                addTrackElement(
                                    at: point
                                )
                            }
                        }
                )
            }
            .aspectRatio(
                1,
                contentMode: .fit
            )
            
            
            // MARK: - Buttons
            
            HStack {
                
                Button("Undo") {
                    undo()
                }
                
                
                Spacer()
                
                
                Button("Clear") {
                    clear()
                }
                
                
                Spacer()
                
                
                Button("Save Map") {
                    onSave()
                }
            }
            
            
            // MARK: - Info
            
            switch editorMode {
                
            case .track:
                
                Text(
                    "\(trackPoints.count) track points"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                
                
            case .coin:
                
                Text(
                    "\(coinCount) coins"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                
                
            case .itemBox:
                
                Text(
                    "\(itemBoxCount) itemboxes"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    
    
    // MARK: - Track
    
    private func addTrackPoint(
        _ point: MapPoint
    ) {
        
        if let last = trackPoints.last {
            
            let dx =
                point.x - last.x
            
            let dy =
                point.y - last.y
            
            
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
    
    
    // MARK: - Elements
    
    private func addTrackElement(
        at point: MapPoint
    ) {
        
        let type: MapTrackElementType
        
        
        switch editorMode {
            
        case .coin:
            type = .coin
            
        case .itemBox:
            type = .itemBox
            
        case .track:
            return
        }
        
        
        let element = MapTrackElement(
            id: UUID(),
            type: type,
            x: point.x,
            y: point.y
        )
        
        
        trackElements.append(element)
    }
    
    
    // MARK: - Undo
    
    private func undo() {
        
        switch editorMode {
            
        case .track:
            
            if trackPoints.isEmpty == false {
                trackPoints.removeLast()
            }
            
            
        case .coin:
            
            if let index =
                trackElements.lastIndex(
                    where: {
                        $0.type == .coin
                    }
                ) {
                
                trackElements.remove(
                    at: index
                )
            }
            
            
        case .itemBox:
            
            if let index =
                trackElements.lastIndex(
                    where: {
                        $0.type == .itemBox
                    }
                ) {
                
                trackElements.remove(
                    at: index
                )
            }
        }
    }
    
    
    // MARK: - Clear
    
    private func clear() {
        
        switch editorMode {
            
        case .track:
            trackPoints.removeAll()
            
        case .coin:
            trackElements.removeAll {
                $0.type == .coin
            }
            
        case .itemBox:
            trackElements.removeAll {
                $0.type == .itemBox
            }
        }
    }
    
    
    // MARK: - Counts
    
    private var coinCount: Int {
        
        trackElements.filter {
            $0.type == .coin
        }
        .count
    }
    
    
    private var itemBoxCount: Int {
        
        trackElements.filter {
            $0.type == .itemBox
        }
        .count
    }
}
