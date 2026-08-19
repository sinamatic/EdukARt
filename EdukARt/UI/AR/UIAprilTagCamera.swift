//
//  UIAprilTagCamera.swift
//  EdukARt
//

import ARKit
import RealityKit
import SwiftUI

struct UIAprilTagCamera: UIViewRepresentable {
    
    @ObservedObject var detectionSession: AprilTagDetectionSession
    
    @ObservedObject var simulatedRobot:
        SimulatedRobotController
    
    var map: GameMap? = nil
    var referenceWorldTransform: simd_float4x4? = nil
    
    var removedElementIDs: Set<UUID> = []

    var showSimulatedRobot = false
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    
    final class Coordinator {
        var didDrawMapContent = false
        var didDrawSimulatedRobot = false

    }
    
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(
            frame: .zero,
            cameraMode: .ar,
            automaticallyConfigureSession: false
        )
        
        let configuration = ARWorldTrackingConfiguration()
        
        arView.session.delegate = detectionSession
        
        arView.session.run(
            configuration,
            options: [
                .resetTracking,
                .removeExistingAnchors
            ]
        )
        
        return arView
    }
    
    
    func updateUIView(
        _ uiView: ARView,
        context: Context
    ) {
        UIARTrackElements.remove(
            elementIDs: removedElementIDs,
            from: uiView
        )

        if showSimulatedRobot {
            if uiView.scene.findEntity(
                named: "SimulatedEduard"
            ) == nil,
               let referenceWorldTransform {
                
                let robot =
                    EduardRobotSimulation()
                
                UIARSimulatedRobot.draw(
                    robot: robot,
                    referenceWorldTransform:
                        referenceWorldTransform,
                    in: uiView
                )
            }
            
            UIARSimulatedRobot.update(
                simulatedRobot: simulatedRobot,
                in: uiView
            )
        } else {
            UIARSimulatedRobot.remove(
                from: uiView
            )
        }
        
        guard context.coordinator.didDrawMapContent == false else {
            return
        }
        
        guard let map else {
            return
        }
        
        guard let referenceWorldTransform else {
            return
        }
        
        
        UIARTrack.draw(
            map: map,
            referenceWorldTransform: referenceWorldTransform,
            in: uiView
        )
        
        
        UIARTrackElements.draw(
            elements: map.trackElements,
            referenceWorldTransform: referenceWorldTransform,
            in: uiView
        )
        context.coordinator.didDrawMapContent = true
    }
    
    
    static func dismantleUIView(
        _ uiView: ARView,
        coordinator: Coordinator
    ) {
        uiView.session.pause()
    }
}
