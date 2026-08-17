//
//  UIMapLocalization.swift
//  EdukARt
//

import SwiftUI
import UIKit
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
    
    @State private var removedElementIDs: Set<UUID> = []
    @State private var isItemboxEffectActive = false

    private let collisionController =
        TrackCollisionController()
    
    
    var body: some View {
        ZStack {
            
            UIAprilTagCamera(
                detectionSession: detectionSession,
                map: map,
                referenceWorldTransform: referenceWorldTransform,
                removedElementIDs: removedElementIDs
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
            checkRobotCollision(in: tags)
        }
    }
    
    
    // MARK: - Scan Reference Card
    
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
    
    
    // MARK: - Localized Card
    
    private var localizedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text(map.name)
                .font(.headline)
            
            Text("Map localized")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
            
            UI2DMapPreview(
                map: map,
                robotPosition: robotPosition,
                removedElementIDs: removedElementIDs
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
    
    
    // MARK: - Reference Tag Detection
    
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
    
    
    // MARK: - Robot Position
    
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
    
    
    // MARK: - Robot Collision

    private func checkRobotCollision(
        in tags: [DetectedAprilTag]
    ) {
        
        guard let referenceWorldTransform else {
            return
        }
        
        guard let robotTag = tags.first(
            where: {
                $0.id == 0
            }
        ) else {
            return
        }
        
        let localization = MapLocalization(
            referenceWorldTransform:
                referenceWorldTransform
        )
        
        let position = localization.mapPosition(
            from: robotTag.worldTransform
        )
        
        let activeElements = map.trackElements.filter {
            removedElementIDs.contains($0.id) == false
        }
        
        collisionController.checkCollisions(
            robotPosition: position,
            elements: activeElements
        ) { element in
            
            handleCollision(
                with: element
            )
        }
    }


    // MARK: - Collision Reaction

    private func handleCollision(
        with element: MapTrackElement
    ) {
        
        // Element sofort vom Spielfeld entfernen
        removedElementIDs.insert(
            element.id
        )
        
        triggerCollisionFeedback()
        
        switch element.type {
            
        case .coin:
            
            print("Coin collected")
            
            flashCoinCollection()
            
        case .itemBox:
            
            print("Itembox collected")
            
            itemBoxCollision()
        }
    }
    
    
    private func triggerCollisionFeedback() {
        let generator = UIImpactFeedbackGenerator(
            style: .medium
        )
        
        generator.prepare()
        generator.impactOccurred()
    }
    
    
    private func flashCoinCollection() {
        guard controller.isConnected else {
            print("Robot is not ready for coin light feedback")
            return
        }
        
        let previousMode = controller.lightController.activeMode
        let previousColor = controller.lightController.allLightsColor
        
        controller.lightController.setAllLightsColor(
            red: 0,
            green: 255,
            blue: 0
        )
        
        controller.sendLightMode(
            .rotation
        )
        
        Task {
            try? await Task.sleep(
                for: .milliseconds(450)
            )
            
            await MainActor.run {
                controller.lightController.setAllLightsColor(
                    red: previousColor.red,
                    green: previousColor.green,
                    blue: previousColor.blue
                )
                
                controller.sendLightMode(
                    previousMode
                )
            }
        }
    }
    
    
    // MARK: - Itembox Effect (old)

    private func spinRobot() {
        
        guard controller.driveMode == .mechanum else {
            print("Spin requires Mechanum mode")
            return
        }
        
        guard controller.isConnected && controller.isEnabled else {
            print("Robot is not ready")
            return
        }
        
        controller.stopJoystick()
        controller.startMechanumRotation(.right)
        
        Task {
            try? await Task.sleep(
                for: .seconds(2)
            )
            
            controller.stopMechanumRotation()
        }
    }
    
    // MARK: - Itembox Collision

    private func itemBoxCollision() {
        
        guard isItemboxEffectActive == false else {
            return
        }
        
        guard controller.driveMode == .mechanum else {
            print("Itembox effect requires Mechanum mode")
            return
        }
        
        guard controller.isConnected,
              controller.isEnabled else {
            print("Robot is not ready")
            return
        }
        
        isItemboxEffectActive = true
        
        controller.stopJoystick()
        
        
        Task {
            
            // 1. Rechts blinken + rechts drehen
            
            controller.sendLightMode(
                .flashRight
            )
            
            controller.startMechanumRotation(
                .right
            )
            
            try? await Task.sleep(
                for: .seconds(1)
            )
            
            controller.stopMechanumRotation()
            
            
            // 2. Links blinken + links drehen
            
            controller.sendLightMode(
                .flashLeft
            )
            
            controller.startMechanumRotation(
                .left
            )
            
            try? await Task.sleep(
                for: .seconds(1)
            )
            
            controller.stopMechanumRotation()
            
            
            // 3. Rechts blinken + rechts drehen
            
            controller.sendLightMode(
                .flashRight
            )
            
            controller.startMechanumRotation(
                .right
            )
            
            try? await Task.sleep(
                for: .seconds(1)
            )
            
            controller.stopMechanumRotation()
            
            
            // Licht wieder normal
            
            controller.sendLightMode(
                .enabled
            )
            
            isItemboxEffectActive = false
        }
    }
    
    
    // MARK: - Average Reference Transform
    
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
    
    
    // MARK: - Reference Scan Guide
    
    private var referenceScanGuide: some View {
        
        VStack {
            
            Spacer()
            
            
            VStack(spacing: 20) {
                
                Text(
                    "Align Reference Tag #\(map.referenceTagID)"
                )
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
    
    
    // MARK: - Current Reference Tag
    
    private var currentReferenceTag: DetectedAprilTag? {
        
        detectionSession.detectedTags.first {
            $0.id == map.referenceTagID
        }
    }
    
    
    // MARK: - Reference Guide Text
    
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
    
    
    // MARK: - Reference Guide Color
    
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
