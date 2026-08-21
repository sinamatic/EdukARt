//
//  CameraARView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//

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
            classification: .floor,
            minimumBounds: [0.3, 0.3]
        )

        do {
            let eduard =
                try Entity.load(
                    named: "Eduard"
                )

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
