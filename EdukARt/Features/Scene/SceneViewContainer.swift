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
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)

        let anchor = context.coordinator.makeScene(from: world)
        arView.scene.anchors.append(anchor)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateScene(from: world, in: uiView)
    }
}
