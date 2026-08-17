//
//  UIMapLocalization.swift
//  EdukARt
//

import SwiftUI
import simd



struct UIMapLocalization: View {
    
    let map: GameMap
    let onBack: () -> Void
    
    @ObservedObject var controller: RobotController

    @StateObject private var detectionSession =
        AprilTagDetectionSession()
    
    @State private var referenceWorldTransform: simd_float4x4?
    
    @State private var referenceSamples: [simd_float4x4] = []
    private let requiredSamples = 30

    private let targetDistance = 0.8
    private let distanceTolerance = 0.12

    private let centerTolerance = 0.08
    
    
    var body: some View {
        ZStack {
            
            UIAprilTagCamera(
                detectionSession: detectionSession,
                map: map,
                referenceWorldTransform: referenceWorldTransform
            )
            .ignoresSafeArea()
            
            if referenceWorldTransform == nil {
                       referenceScanGuide
                   }
                        
            VStack {
                
                if referenceWorldTransform == nil {
                    scanReferenceCard
                } else {
                    localizedCard
                }
                
                Spacer()
            }
            .padding()
            
            
            if referenceWorldTransform != nil {
                VStack {
                    Spacer()
                    
                    UIRobotJoystick(controller: controller) { input in
                        controller.updateJoystickInput(
                            x: Float(input.x),
                            y: Float(input.y)
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
        .background(.black.opacity(0.5))
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
        .background(.black.opacity(0.5))
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }
    
    
    private func detectReferenceTag(
        in tags: [DetectedAprilTag]
    ) {
        
        // Map wurde bereits lokalisiert
        guard referenceWorldTransform == nil else {
            return
        }
        
        
        // Reference Tag suchen
        guard let referenceTag = tags.first(
            where: {
                $0.id == map.referenceTagID
            }
        ) else {
            referenceSamples.removeAll()
            return
        }
        
        
        let distance = referenceTag.distance
        
        
        // Richtiger Abstand?
        let correctDistance =
            abs(distance - targetDistance)
            <= distanceTolerance
        
        
        // Genug in der Bildmitte?
        let correctPosition =
            referenceTag.centerOffset
            <= centerTolerance
        
        
        guard correctDistance && correctPosition else {
            referenceSamples.removeAll()
            return
        }
        
        
        // Gute Messung sammeln
        referenceSamples.append(
            referenceTag.worldTransform
        )
        
        
        // Noch nicht genug Messungen
        guard referenceSamples.count >= requiredSamples else {
            return
        }
        
        
        // Stabile Pose berechnen
        referenceWorldTransform =
            averageTransform(referenceSamples)
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
    
    private func averageTransform(
        _ transforms: [simd_float4x4]
    ) -> simd_float4x4 {
        
        guard let first = transforms.first else {
            return matrix_identity_float4x4
        }
        
        
        var position = SIMD3<Float>.zero
        
        
        for transform in transforms {
            
            position += SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
        }
        
        
        position /= Float(transforms.count)
        
        
        var result = first
        
        result.columns.3 = SIMD4<Float>(
            position.x,
            position.y,
            position.z,
            1
        )
        
        
        return result
    }
    
    private var referenceScanGuide: some View {
        
        VStack {
            
            Spacer()
            
            
            VStack(spacing: 20) {
                
                Text("Align Reference Tag #\(map.referenceTagID)")
                    .font(.headline)
                
                
                RoundedRectangle(
                    cornerRadius: 12
                )
                .stroke(
                    referenceGuideColor,
                    lineWidth: 4
                )
                .frame(
                    width: 110,
                    height: 110
                )
                
                
                Text(referenceGuideText)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                
                
                if referenceSamples.isEmpty == false {
                    
                    ProgressView(
                        value: Double(referenceSamples.count),
                        total: Double(requiredSamples)
                    )
                    .tint(.green)
                }
            }
            .foregroundStyle(.white)
            .padding(24)
            .background(
                .black.opacity(0.7)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16
                )
            )
            
            
            Spacer()
        }
        .padding()
    }
    
    private var currentReferenceTag: DetectedAprilTag? {
        
        detectionSession.detectedTags.first {
            $0.id == map.referenceTagID
        }
    }
    
    private var referenceGuideText: String {
        
        guard let tag = currentReferenceTag else {
            return "Point the camera at the reference tag."
        }
        
        
        let distance = tag.distance
        
        
        if distance > targetDistance + distanceTolerance {
            return "Move closer."
        }
        
        
        if distance < targetDistance - distanceTolerance {
            return "Move further away."
        }
        
        
        if tag.centerOffset > centerTolerance {
            return "Move the tag into the center."
        }
        
        
        return "Hold still..."
    }
    
    private var referenceGuideColor: Color {
        
        guard let tag = currentReferenceTag else {
            return .white
        }
        
        let distance = tag.distance
        
        
        let correctDistance =
            abs(distance - targetDistance)
            <= distanceTolerance
        
        
        let correctPosition =
            tag.centerOffset
            <= centerTolerance
        
        
        if correctDistance && correctPosition {
            return .green
        }
        
        
        return .white
    }
}


