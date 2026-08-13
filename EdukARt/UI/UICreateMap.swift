//
//  UICreateMap.swift
//  EdukARt
//

import SwiftUI

struct UICreateMap: View {
    
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
                
                
                VStack(spacing: 10) {
                    
                    Text("Scan AprilTags")
                        .font(.headline)
                    
                    // show permanent added tags
                    Text(
                        "\(detectionSession.scannedTags.count) map tags scanned"
                    )
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    
                    // temporary show all saved IDs
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
                }
                .foregroundStyle(.white)
                .padding(20)
                .background(.black.opacity(0.7))
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
                .padding()
            }
        }
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
}
