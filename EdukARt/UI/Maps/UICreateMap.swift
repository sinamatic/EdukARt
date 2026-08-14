//
//  UICreateMap.swift
//  EdukARt
//

import SwiftUI
import simd

struct UICreateMap: View {
    
    @ObservedObject var mapStore: MapStore
    
    @StateObject private var detectionSession =
        AprilTagDetectionSession()
    
    @State private var scanFinished = false
    @State private var mapName = ""
    @State private var previewMap: GameMap?
    @State private var saveMessage = ""
    
    
    var body: some View {
        ZStack {
            
            if scanFinished == false {
                
                UIAprilTagCamera(
                    detectionSession: detectionSession
                )
                .ignoresSafeArea()
                
            } else {
                
                Color.black
                    .ignoresSafeArea()
            }
            
            
            VStack {
                
                Spacer()
                
                
                if scanFinished == false {
                    
                    scanCard
                    
                } else if let previewMap {
                    
                    UITrackEditor(
                        map: previewMap
                    )
                    
                } else {
                    
                    mapNameCard
                }
            }
            .padding()
        }
    }
    
    
    // MARK: - Scan
    
    private var scanCard: some View {
        VStack(spacing: 10) {
            
            Text("Scan AprilTags")
                .font(.headline)
            
            
            Text(
                "\(detectionSession.scannedTags.count) map tags scanned"
            )
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
            
            
            Text(
                detectionSession.scannedTags
                    .map { "#\($0.id)" }
                    .joined(separator: ", ")
            )
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
            
            
            if detectionSession.detectedTags.isEmpty {
                
                Text("No AprilTags detected")
                
            } else {
                
                ForEach(detectionSession.detectedTags) { tag in
                    
                    VStack(alignment: .leading, spacing: 4) {
                        
                        HStack {
                            
                            Text("Tag #\(tag.id)")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text(
                                String(
                                    format: "%.2f m",
                                    tag.distance
                                )
                            )
                        }
                        
                        
                        Text(sourceName(tag.source))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        
                        Text(
                            String(
                                format: "World x: %.2f   y: %.2f   z: %.2f",
                                tag.worldPosition.x,
                                tag.worldPosition.y,
                                tag.worldPosition.z
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            
            
            Button("Finish Scan") {
                scanFinished = true
            }
            .disabled(
                detectionSession.scannedTags.isEmpty
            )
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(.black.opacity(0.7))
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }
    
    
    // MARK: - Map Name
    
    private var mapNameCard: some View {
        VStack(spacing: 12) {
            
            Text("Map Name")
                .font(.headline)
            
            
            Text(
                "\(detectionSession.scannedTags.count) tags scanned"
            )
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
            
            
            TextField(
                "Enter map name",
                text: $mapName
            )
            .textFieldStyle(.roundedBorder)
            
            
            Button("Create Map") {
                previewMap = createMap()
            }
            .disabled(
                mapName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            )
            
            
            Button("Back to Scan") {
                scanFinished = false
            }
            
            
            if saveMessage.isEmpty == false {
                Text(saveMessage)
                    .font(.caption)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(.black.opacity(0.75))
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }
    
    
    // MARK: - Source
    
    private func sourceName(
        _ source: AprilTagSource
    ) -> String {
        
        switch source {
        case .iPhone:
            return "iPhone"
            
        case .robotCamera:
            return "Robot Camera"
        }
    }
    
    
    // MARK: - Create Map
    
    private func createMap() -> GameMap? {
        
        let scannedTags = detectionSession.scannedTags
        
        
        guard scannedTags.isEmpty == false else {
            return nil
        }
        
        
        guard let referenceTag = scannedTags.min(
            by: { $0.id < $1.id }
        ) else {
            return nil
        }
        
        
        let referenceInverse =
            referenceTag.worldTransform.inverse
        
        
        let mapTags = scannedTags.map { tag in
            
            let relativeTransform =
                referenceInverse * tag.worldTransform
            
            
            return MapAprilTag(
                id: tag.id,
                x: relativeTransform.columns.3.x,
                y: relativeTransform.columns.3.y,
                z: relativeTransform.columns.3.z
            )
        }
        
        
        return GameMap(
            name: mapName,
            referenceTagID: referenceTag.id,
            aprilTags: mapTags
        )
    }
}
