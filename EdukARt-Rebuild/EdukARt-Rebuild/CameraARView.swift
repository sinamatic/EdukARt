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

struct CameraARView: UIViewRepresentable {
    
    @ObservedObject var eduardModelStore: EduardModelStore

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

        context.coordinator.anchorSubscription =
            arView.scene.subscribe(
                to: SceneEvents.AnchoredStateChanged.self
            ) { event in

                guard event.anchor === anchor else {
                    return
                }

                if event.isAnchored {
                    PerformanceLogger.shared.end(
                        "Find Floor Anchor"
                    )

                    print("✅ Floor anchor found")
                }
            }
        
        
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
    
    final class Coordinator {
        var anchorSubscription: (any Cancellable)?
    }
    
}
