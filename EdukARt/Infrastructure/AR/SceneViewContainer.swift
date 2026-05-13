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
    @ObservedObject var game: Game
    let isDebugEnabled: Bool

    func makeCoordinator() -> SceneCoordinator {
        SceneCoordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false) // hide robot behind real objects
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic

        let debugController = SceneDebugController()
        context.coordinator.debugController = debugController
        debugController.configureSession(configuration)

        arView.session.run(configuration)

        arView.environment.sceneUnderstanding.options.insert(.physics)
        
        let anchor = context.coordinator.makeScene(from: game)
        arView.scene.anchors.append(anchor)
        context.coordinator.loadInitialObstacles(from: game)
        
        game.canMoveInRealWorld = { [weak arView, weak coordinator = context.coordinator] currentPosition, candidatePosition in
            guard let arView, let coordinator else {
                return true
            }

            return coordinator.canMoveInRealWorld(
                from: currentPosition,
                to: candidatePosition,
                in: arView
        )
        }

        debugController.updateDebugState(isEnabled: isDebugEnabled, in: arView)

        
        return arView
        
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateScene(from: game, in: uiView)
        context.coordinator.debugController?.updateDebugState(isEnabled: isDebugEnabled, in: uiView)
    }
}
