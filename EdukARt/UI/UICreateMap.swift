//
//  UICreateMap.swift
//  EdukARt
//

import SwiftUI
import simd

struct UICreateMap: View {
    
    @State private var mapName = ""
    @State private var saveMessage = ""
    @State private var previewMap: GameMap?
    
    @StateObject private var detectionSession =
        AprilTagDetectionSession()
    
    
    var body: some View {
        ZStack {
            
            UIAprilTagCamera(
                detectionSession: detectionSession
            )
            .ignoresSafeArea()
            
            
            VStack {
                
                Spacer()
                
                if let previewMap {
                    previewCard(previewMap)
                } else {
                    scanCard
                }
            }
            .padding()
        }
    }
    
    
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
            
            
            TextField(
                "Map name",
                text: $mapName
            )
            .textFieldStyle(.roundedBorder)
            
            
            Button("Create Map") {
                previewMap = createMap()
            }
            .disabled(
                mapName.isEmpty ||
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
    
    
    private func previewCard(
        _ map: GameMap
    ) -> some View {
        
        VStack(alignment: .leading, spacing: 10) {
            
            Text(map.name)
                .font(.headline)
            
            
            Text(
                "Reference Tag: #\(map.referenceTagID)"
            )
            .font(.subheadline)
            
            
            ForEach(map.aprilTags) { tag in
                
                Text(
                    String(
                        format: "#%d  x: %.2f  y: %.2f  z: %.2f",
                        tag.id,
                        tag.x,
                        tag.y,
                        tag.z
                    )
                )
                .font(.caption)
            }
            
            
            Button("Back to Scan") {
                previewMap = nil
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(.black.opacity(0.75))
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }
    
    
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
