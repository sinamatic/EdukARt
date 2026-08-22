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

    func makeUIView(context: Context) -> ARView {

        let arView = ARView(
            frame: .zero,
            cameraMode: .ar,
                       automaticallyConfigureSession: false
        )

        let configuration =
            ARWorldTrackingConfiguration()

        configuration.planeDetection = [
            .horizontal
        ]

        arView.session.run(
            configuration
        )

        let anchor = AnchorEntity(
            plane: .horizontal,
            classification: .floor,
            minimumBounds: [0.3, 0.3]
        )
        
        arView.scene.addAnchor(anchor)
        
        let simulation = EduardSimulation()

        Task {
            do {
                let eduard = try await simulation.loadEntity()
                anchor.addChild(eduard)
            } catch {
                print("Could not load Eduard:", error)
            }
        }

        

        return arView
        
        
    }

    func updateUIView(
        _ uiView: ARView,
        context: Context
    ) {
    }
    
    
}


