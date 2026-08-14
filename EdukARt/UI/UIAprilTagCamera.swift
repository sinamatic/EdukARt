//
//  UIAprilTagCamera.swift
//  EdukARt
//

import ARKit
import RealityKit
import SwiftUI

struct UIAprilTagCamera: UIViewRepresentable {
    
    @ObservedObject var detectionSession: AprilTagDetectionSession
    
    var map: GameMap? = nil
    var referenceWorldTransform: simd_float4x4? = nil
    
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
    }
    static func dismantleUIView(
        _ uiView: ARView,
        coordinator: ()
    ) {
        uiView.session.pause()
    }
}
