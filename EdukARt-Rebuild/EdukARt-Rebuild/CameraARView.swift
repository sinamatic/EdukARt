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
            frame: .zero
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
            classification: .any,
            minimumBounds: [0.2, 0.2]
        )
        
        let simulation = EduardSimulation()
        
        do {
            let eduard = try simulation.loadEntity()
                           anchor.addChild(eduard)

        } catch {
            print(
                "Could not load Eduard model:",
                error
            )
        }

        arView.scene.addAnchor(anchor)

        return arView
        
        
    }

    func updateUIView(
        _ uiView: ARView,
        context: Context
    ) {
    }
    
    
}


