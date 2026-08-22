//
//  CameraARView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//  https://developer.apple.com/documentation/realitykit/loading-entities-from-a-file
//  https://developer.apple.com/documentation/realitykit/entity/load(named:in:)

import SwiftUI
import RealityKit
import ARKit
import Combine

import SwiftUIJoystick

struct CameraARView: UIViewRepresentable {
    
    @ObservedObject var eduardModelStore: EduardModelStore
    
    @ObservedObject var joystickMonitor: JoystickMonitor
    @ObservedObject var sidewaysJoystickMonitor: JoystickMonitor

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        
        PerformanceLogger.shared.end(
            "Button to CameraARView"
        )

        PerformanceLogger.shared.start(
            "Create ARView"
        )
       

        let arView = ARView(
            frame: .zero,
            cameraMode: .ar,
                       automaticallyConfigureSession: false
        )
        
        PerformanceLogger.shared.end(
            "Create ARView"
        )
        
        arView.debugOptions.insert(
            .showStatistics
        )
        
        
        

        let configuration =
            ARWorldTrackingConfiguration()

        configuration.planeDetection = [
            .horizontal
        ]

        PerformanceLogger.shared.start(
            "Start ARSession"
        )
        arView.session.run(
            configuration
        )
        
        PerformanceLogger.shared.end(
            "Start ARSession"
        )

        PerformanceLogger.shared.start(
            "Find Floor Anchor"
        )

        let anchor = AnchorEntity(
            plane: .horizontal,
            classification: .floor,
            minimumBounds: [0.3, 0.3]
        )
        
        arView.scene.addAnchor(anchor)

        
        
        // Load preloaded eduard
        if let model = eduardModelStore.model {
            let eduard = model.clone(recursive: true)
            anchor.addChild(eduard)
            
            context.coordinator.eduard = eduard

            print("Used preloaded Eduard model")
            
            
            
        } else {
            print("Eduard model is not loaded yet")
        }
        
        
        
        

        
        

        return arView
        
        
    }

    func updateUIView(
        _ uiView: ARView,
        context: Context
    ) {

        guard let eduard = context.coordinator.eduard else {
            return
        }

        let forward =
            Float(
                joystickMonitor.xyPoint.y
                / 180
            )

        let sideways =
            Float(
                sidewaysJoystickMonitor.xyPoint.x
                / 120
            )

        let movementSpeed: Float = 0.02

        eduard.position.x += sideways * movementSpeed
        eduard.position.z += forward * movementSpeed

//        let rotationX =
//            Float(
//                sidewaysJoystickMonitor.xyPoint.x
//                / 120
//            )
//
//        let rotationSpeed: Float = 0.03
//
//        if abs(rotationX) > 0.05 {
//
//            let rotation =
//                simd_quatf(
//                    angle: rotationX * rotationSpeed,
//                    axis: SIMD3<Float>(0, 1, 0)
//                )
//
//            eduard.transform.rotation =
//                rotation * eduard.transform.rotation
//        }
    }
    
    
    final class Coordinator {
        var anchorSubscription: EventSubscription?
        var eduard: Entity?
    }
    }
    
