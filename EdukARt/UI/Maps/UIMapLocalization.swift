//
//  UIMapLocalization.swift
//  EdukARt
//

import SwiftUI
import simd

struct UIMapLocalization: View {
    
    let map: GameMap
    let onBack: () -> Void
    
    @StateObject private var detectionSession =
        AprilTagDetectionSession()
    
    @State private var referenceWorldTransform: simd_float4x4?
    
    
    var body: some View {
        ZStack {
            
            UIAprilTagCamera(
                detectionSession: detectionSession
            )
            .ignoresSafeArea()
            
            
            VStack {
                
                Spacer()
                
                if referenceWorldTransform == nil {
                    scanReferenceCard
                } else {
                    localizedCard
                }
            }
            .padding()
            
            
            if referenceWorldTransform != nil {
                VStack {
                    Spacer()
                    
                    UIRobotJoystick { input in
                        print(
                            "Joystick:",
                            input.x,
                            input.y
                        )
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onReceive(
            detectionSession.$detectedTags
        ) { tags in
            detectReferenceTag(in: tags)
        }
    }
    
    
    private var scanReferenceCard: some View {
        VStack(spacing: 12) {
            
            Text(map.name)
                .font(.headline)
            
            
            Text("Scan Reference Tag")
                .font(.title3.bold())
            
            
            Text("#\(map.referenceTagID)")
                .font(.largeTitle.bold())
                .foregroundStyle(.green)
            
            
            Text(
                "Point the camera at AprilTag #\(map.referenceTagID) to align the map."
            )
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.7))
            
            
            Button("Back") {
                onBack()
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(.black.opacity(0.75))
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }
    
    
    private var localizedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text(map.name)
                .font(.headline)
            
            
            Text("Map localized")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
            
            
            UI2DMapPreview(
                map: map,
                robotPosition: robotPosition
            )
            .frame(height: 300)
            
            
            if let robotPosition {
                
                Text("Robot #0")
                    .font(.headline)
                
                Text(
                    String(
                        format: "x: %.2f   y: %.2f   z: %.2f",
                        robotPosition.x,
                        robotPosition.y,
                        robotPosition.z
                    )
                )
                .font(.caption)
            }
            
            
            Button("Back") {
                onBack()
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(.black.opacity(0.75))
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }
    
    
    private func detectReferenceTag(
        in tags: [DetectedAprilTag]
    ) {
        
        guard referenceWorldTransform == nil else {
            return
        }
        
        
        guard let referenceTag = tags.first(
            where: {
                $0.id == map.referenceTagID
            }
        ) else {
            return
        }
        
        
        referenceWorldTransform =
            referenceTag.worldTransform
    }
    
    
    private var robotPosition: SIMD3<Float>? {
        
        guard let referenceWorldTransform else {
            return nil
        }
        
        
        guard let robotTag = detectionSession.detectedTags.first(
            where: {
                $0.id == 0
            }
        ) else {
            return nil
        }
        
        
        let localization = MapLocalization(
            referenceWorldTransform:
                referenceWorldTransform
        )
        
        
        return localization.mapPosition(
            from: robotTag.worldTransform
        )
    }
}
