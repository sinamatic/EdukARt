//
//  CameraARSceneReconstruction.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//
//  Sources:
//  Apple – Implementing scene understanding and reconstruction in your RealityKit app
//  https://developer.apple.com/documentation/realitykit/realitykit-scene-understanding
//
//  Apple – Visualizing and interacting with a reconstructed scene
//  https://developer.apple.com/documentation/arkit/visualizing-and-interacting-with-a-reconstructed-scene
//
// Description: Shows Mesh on Objects and sticks Cubes on floor and walls when you touch somewhere

import UIKit
import SwiftUI
import ARKit
import RealityKit


final class CameraARSceneReconstruction: UIViewController, ARSessionDelegate {

    private var arView: ARView!


    override func viewDidLoad() {
        super.viewDidLoad()

        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)

        // Apple configures the ARSession manually in its scene-reconstruction sample.
        arView.automaticallyConfigureSession = false

        let configuration = ARWorldTrackingConfiguration()

        // Plane detection can improve the reconstructed mesh by smoothing
        // detected planar surfaces such as floors and walls.
        configuration.planeDetection = [.horizontal, .vertical]

        // Scene reconstruction creates a polygonal mesh that estimates
        // the shape of the physical environment.
        //
        // meshWithClassification additionally classifies parts of the mesh,
        // for example as floor, wall, table, seat, window, or ceiling.
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(
            .meshWithClassification
        ) {
            configuration.sceneReconstruction = .meshWithClassification
        }

        // Occlusion uses reconstructed real-world geometry to hide
        // virtual content that is located behind it.
        arView.environment.sceneUnderstanding.options.insert(.occlusion)

        // Collision allows the reconstructed geometry to participate
        // in collision queries such as raycasting.
        arView.environment.sceneUnderstanding.options.insert(.collision)

        // Physics allows virtual objects to physically interact
        // with reconstructed real-world geometry.
        arView.environment.sceneUnderstanding.options.insert(.physics)

        // Allows virtual lighting to affect reconstructed surfaces.
        arView.environment.sceneUnderstanding.options.insert(.receivesLighting)

        // Shows the reconstructed mesh.
        // Apple recommends this only for debugging / visualization.
        arView.debugOptions.insert(.showSceneUnderstanding)

        // Receive ARSession callbacks such as newly added mesh anchors.
        arView.session.delegate = self

        arView.session.run(configuration)

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(placeObject(_:))
        )

        arView.addGestureRecognizer(tapGesture)
    }


    @objc private func placeObject(_ gesture: UITapGestureRecognizer) {

        let tapLocation = gesture.location(in: arView)

        // Cast a ray from the camera through the tapped screen position.
        //
        // Apple uses .estimatedPlane together with .any when raycasting
        // against reconstructed real-world surfaces.
        guard let result = arView.raycast(
            from: tapLocation,
            allowing: .estimatedPlane,
            alignment: .any
        ).first else {
            return
        }

        let mesh = MeshResource.generateBox(size: 0.10)

        let material = SimpleMaterial(
            color: .systemBlue,
            isMetallic: false
        )

        let box = ModelEntity(
            mesh: mesh,
            materials: [material]
        )

        // The raycast result contains the transformation of the
        // intersection point in ARKit's world coordinate system.
        let anchor = AnchorEntity(world: result.worldTransform)

        anchor.addChild(box)
        arView.scene.addAnchor(anchor)
    }


    func session(
        _ session: ARSession,
        didAdd anchors: [ARAnchor]
    ) {

        for anchor in anchors {

            guard let meshAnchor = anchor as? ARMeshAnchor else {
                continue
            }

            print(
                "Mesh vertices: \(meshAnchor.geometry.vertices.count)"
            )
        }
    }
}


// MARK: - SwiftUI wrapper

struct CameraARSceneReconstructionView: UIViewControllerRepresentable {

    func makeUIViewController(
        context: Context
    ) -> CameraARSceneReconstruction {

        CameraARSceneReconstruction()
    }


    func updateUIViewController(
        _ uiViewController: CameraARSceneReconstruction,
        context: Context
    ) {
    }
}


#Preview {
    CameraARSceneReconstructionView()
        .ignoresSafeArea()
}
