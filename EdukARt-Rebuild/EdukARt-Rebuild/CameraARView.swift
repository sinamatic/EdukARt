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

struct CameraARView: UIViewRepresentable {
    
    @ObservedObject var eduardModelStore: EduardModelStore

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
    }
    
    
}


