//
//  SceneViewContainer.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import SwiftUI
import ARKit
import RealityKit

struct SceneViewContainer: UIViewRepresentable {
    @ObservedObject var world: GameWorld

    func makeCoordinator() -> SceneCoordinator {
        SceneCoordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false) // hide robot behind real objects
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }

        arView.session.run(configuration)

        arView.environment.sceneUnderstanding.options.insert(.collision)
        arView.environment.sceneUnderstanding.options.insert(.physics)
        
        /*
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        */ // robot disapperas behind real objects
        
        let anchor = context.coordinator.makeScene(from: world)
        arView.scene.anchors.append(anchor)
        
        world.canMoveInRealWorld = { [weak arView, weak coordinator = context.coordinator] currentPosition, candidatePosition in
            guard let arView, let coordinator else {
                return true
            }

            return coordinator.canMoveInRealWorld(
                from: currentPosition,
                to: candidatePosition,
                in: arView
            )
        }

        
        return arView
        
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateScene(from: world, in: uiView)
    }
}
