//
//  SceneDebugController.swift
//  EdukARt
//
//  Created by Codex on 13.08.25.
//

import ARKit
import RealityKit
import UIKit

final class SceneDebugController {
    private let debugAnchor = AnchorEntity(world: .zero)
    private let axisEntity = Entity()
    private var hasAttachedDebugAnchor = false
    private(set) var isDebugEnabled = false

    init() {
        axisEntity.addChild(makeAxisEntity())
        axisEntity.position = SIMD3<Float>(0, 0.02, 0)
        debugAnchor.addChild(axisEntity)
    }

    func configureSession(_ configuration: ARWorldTrackingConfiguration) {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
    }

    func updateDebugState(isEnabled: Bool, in arView: ARView) {
        if hasAttachedDebugAnchor == false {
            arView.scene.anchors.append(debugAnchor)
            hasAttachedDebugAnchor = true
        }

        guard isDebugEnabled != isEnabled else {
            axisEntity.isEnabled = isEnabled
            return
        }

        isDebugEnabled = isEnabled
        axisEntity.isEnabled = isEnabled

        if isEnabled {
            arView.debugOptions.insert(.showWorldOrigin)
            arView.debugOptions.insert(.showSceneUnderstanding)
            arView.debugOptions.insert(.showAnchorGeometry)
        } else {
            arView.debugOptions.remove(.showWorldOrigin)
            arView.debugOptions.remove(.showSceneUnderstanding)
            arView.debugOptions.remove(.showAnchorGeometry)
        }
    }

    private func makeAxisEntity() -> Entity {
        let rootEntity = Entity()
        let axisLength: Float = 0.18
        let axisWidth: Float = 0.004
        let planeSize: Float = 0.16

        let xAxis = ModelEntity(
            mesh: .generateBox(size: [axisLength, axisWidth, axisWidth]),
            materials: [UnlitMaterial(color: .systemRed)]
        )
        xAxis.position = [axisLength / 2, 0, 0]

        let yAxis = ModelEntity(
            mesh: .generateBox(size: [axisWidth, axisLength, axisWidth]),
            materials: [UnlitMaterial(color: .systemGreen)]
        )
        yAxis.position = [0, axisLength / 2, 0]

        let zAxis = ModelEntity(
            mesh: .generateBox(size: [axisWidth, axisWidth, axisLength]),
            materials: [UnlitMaterial(color: .systemBlue)]
        )
        zAxis.position = [0, 0, axisLength / 2]

        let xyPlane = ModelEntity(
            mesh: .generatePlane(width: planeSize, depth: planeSize),
            materials: [makePlaneMaterial(color: UIColor.systemYellow.withAlphaComponent(0.15))]
        )
        xyPlane.position = [planeSize / 2, planeSize / 2, 0]

        let xzPlane = ModelEntity(
            mesh: .generatePlane(width: planeSize, depth: planeSize),
            materials: [makePlaneMaterial(color: UIColor.systemCyan.withAlphaComponent(0.15))]
        )
        xzPlane.position = [planeSize / 2, 0, planeSize / 2]
        xzPlane.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

        let yzPlane = ModelEntity(
            mesh: .generatePlane(width: planeSize, depth: planeSize),
            materials: [makePlaneMaterial(color: UIColor.systemPink.withAlphaComponent(0.15))]
        )
        yzPlane.position = [0, planeSize / 2, planeSize / 2]
        yzPlane.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])

        let origin = ModelEntity(
            mesh: .generateSphere(radius: 0.008),
            materials: [UnlitMaterial(color: .white)]
        )

        rootEntity.addChild(xyPlane)
        rootEntity.addChild(xzPlane)
        rootEntity.addChild(yzPlane)
        rootEntity.addChild(xAxis)
        rootEntity.addChild(yAxis)
        rootEntity.addChild(zAxis)
        rootEntity.addChild(origin)

        return rootEntity
    }

    private func makePlaneMaterial(color: UIColor) -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: color)
        material.blending = .transparent(opacity: PhysicallyBasedMaterial.Opacity(floatLiteral: 0.2))
        material.faceCulling = .none
        return material
    }
}
