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
    let onCameraReady: () -> Void

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
        let shouldWaitForMapOrigin = context.coordinator.configureMapOriginTracking(configuration, for: game.selectedMap)
        context.coordinator.onCameraFrameAvailable = onCameraReady
        if shouldWaitForMapOrigin {
            configuration.planeDetection = []
            configuration.environmentTexturing = .none
            context.coordinator.prepareScene(from: game)
        } else {
            debugController.configureSession(configuration)
        }

        arView.environment.sceneUnderstanding.options.insert(.physics)
        arView.environment.sceneUnderstanding.options.insert(.collision)
        context.coordinator.attach(to: arView)
        arView.session.delegate = context.coordinator

        arView.session.run(configuration)
        
        if shouldWaitForMapOrigin == false {
            let anchor = context.coordinator.makeScene(from: game)
            arView.scene.anchors.append(anchor)
            context.coordinator.markSceneAnchorAdded()
            context.coordinator.loadInitialObstacles(from: game)
        }
        
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
