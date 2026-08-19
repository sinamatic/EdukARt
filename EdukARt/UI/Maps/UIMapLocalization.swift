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

    @ObservedObject var simulatedRobot: SimulatedRobotController
    
    @StateObject private var detectionSession =
        AprilTagDetectionSession()
    
    @State private var referenceWorldTransform: simd_float4x4?
    @State private var realRobotTransform: simd_float4x4?
    @State private var realRobotPosition: SIMD3<Float>?
    
    @State private var removedElementIDs: Set<UUID> = []
    @State private var isItemboxEffectActive = false
    @State private var isOilEffectActive = false
    @State private var isSimulationVisible = false
    @State private var isLiveSyncEnabled = true

    private let collisionController =
        TrackCollisionController()
    
    
    var body: some View {
        ZStack {
            
            UIAprilTagCamera(
                detectionSession: detectionSession,
                simulatedRobot: simulatedRobot,
                map: map,
                referenceWorldTransform:
                    referenceWorldTransform,
                removedElementIDs:
                    removedElementIDs,
                showSimulatedRobot:
                    isSimulationVisible
            )
            .ignoresSafeArea()
            
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
                    HStack {
                        Spacer()
                        simulationControls
                    }
                    Spacer()
                }
                .padding()
            }
            
            
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
            detectRobot(in: tags)
        }
        .onReceive(
            simulatedRobot.$position
        ) { position in
            guard controller.isEnabled == false else {
                return
            }
            
            checkCollision(at: position)
        }
        .onChange(of: controller.isEnabled) { oldValue, newValue in
            if oldValue == true,
               newValue == false {
                synchronizeSimulation()
            }
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
                robotPosition: activeRobotPosition,
                removedElementIDs: removedElementIDs
            )
            .frame(height: 300)
            
            
            if let activeRobotPosition {
                
                Text("Robot #0")
                    .font(.headline)
                
                Text(
                    String(
                        format: "x: %.2f   y: %.2f   z: %.2f",
                        activeRobotPosition.x,
                        activeRobotPosition.y,
                        activeRobotPosition.z
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
        
        
        // Erste Schätzung des Reference Tags verwenden
        guard let referenceTag = tags.first(
            where: {
                $0.id == map.referenceTagID
            }
        ) else {
            return
        }
        
        referenceWorldTransform = referenceTag.worldTransform
        
        if controller.isEnabled == false {
            simulatedRobot.reset()
        }
    }
    
    
    // MARK: - Robot Detection
    
    private func detectRobot(
        in tags: [DetectedAprilTag]
    ) {
        
        guard
            let referenceWorldTransform,
            let robotTag = tags.first(
                where: {
                    $0.id == 0
                }
            )
        else {
            return
        }
        
        let localization =
            AprilTagLocalization(
                referenceWorldTransform:
                    referenceWorldTransform
            )
        
        let robotTransform =
            localization.relativeTransform(
                from: robotTag.worldTransform
            )
        
        realRobotTransform = robotTransform
        realRobotPosition = localization.relativePosition(
            from: robotTag.worldTransform
        )
        
        if controller.isEnabled,
           let realRobotPosition {
            checkCollision(at: realRobotPosition)
        }
        
        if isLiveSyncEnabled &&
           controller.isEnabled &&
           isSimulationVisible {
            synchronizeSimulation(
                with: robotTransform
            )
        }
    }
    
    
    // MARK: - Robot Position
    
    private var activeRobotPosition: SIMD3<Float>? {
        if controller.isEnabled {
            return realRobotPosition
        }
        
        guard referenceWorldTransform != nil else {
            return nil
        }
        
        return simulatedRobot.position
    }
    
    
    // MARK: - Simulation Sync
    
    private var simulationControls: some View {
        HStack(spacing: 8) {
            Button {
                toggleSimulation()
            } label: {
                Image(
                    systemName:
                        isSimulationVisible
                        ? "car.fill"
                        : "car"
                )
                .frame(width: 34, height: 34)
            }
            
            Button {
                synchronizeSimulation()
            } label: {
                Image(
                    systemName: "arrow.triangle.2.circlepath"
                )
                .frame(width: 34, height: 34)
            }
            .disabled(
                isSimulationVisible == false ||
                realRobotTransform == nil
            )
            
            Toggle(
                isOn: $isLiveSyncEnabled
            ) {
                Image(
                    systemName: "link"
                )
            }
            .labelsHidden()
            .frame(width: 44)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.58))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    
    private func toggleSimulation() {
        if isSimulationVisible {
            isSimulationVisible = false
        } else {
            isSimulationVisible = true
            
            if realRobotTransform != nil {
                synchronizeSimulation()
            }
        }
    }
    
    
    private func synchronizeSimulation() {
        guard let realRobotTransform else {
            return
        }
        
        synchronizeSimulation(
            with: realRobotTransform
        )
    }
    
    
    private func synchronizeSimulation(
        with transform: simd_float4x4
    ) {
        
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        
        let rotation = atan2(
            transform.columns.0.y,
            transform.columns.0.x
        )
        
        simulatedRobot.setPose(
            position: position,
            rotation: rotation
        )
    }
    
    
    // MARK: - Robot Collision
    
    private func checkCollision(
        at position: SIMD3<Float>
    ) {
        guard referenceWorldTransform != nil else {
            return
        }
        
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
        
        
        case .oil:
               
            print("Oil collected")
                
            oilCollision()
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
    
    
    // MARK: - Oil Collission

    private func oilCollision() {
        
        guard isOilEffectActive == false else {
            return
        }
        
        guard controller.driveMode == .mechanum else {
            print("Oil effect requires Mechanum mode")
            return
        }
        
        isOilEffectActive = true
        
        controller.stopJoystick()
        
        Task {
            controller.sendLightMode(
                .rainbow
            )
            
            controller.startMechanumRotation(
                .right
            )
            
            try? await Task.sleep(
                for: .seconds(1)
            )
            
            controller.stopMechanumRotation()
            
            controller.sendLightMode(
                .enabled
            )
            
            isOilEffectActive = false
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
}
