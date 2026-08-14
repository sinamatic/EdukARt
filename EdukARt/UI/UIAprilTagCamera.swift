//
//  UIAprilTagCamera.swift
//  EdukARt
//

import ARKit
import RealityKit
import SwiftUI

struct UIAprilTagCamera: UIViewRepresentable {
    
    @ObservedObject var detectionSession: AprilTagDetectionSession
    
    
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
    }
    static func dismantleUIView(
        _ uiView: ARView,
        coordinator: ()
    ) {
        uiView.session.pause()
    }
}
