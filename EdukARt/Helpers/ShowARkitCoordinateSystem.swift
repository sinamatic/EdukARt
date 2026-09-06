//
//  ShowARkitCoordinateSystem.swift
//  EdukARt-Rebuild
//
//  Visualizes ARKit's world coordinate system independently from the game,
//  robot, AprilTag, joystick, and minimap coordinate systems.
//

import SwiftUI
import RealityKit
import ARKit
import UIKit

struct ShowARkitCoordinateSystem: View {

    @State private var selectedCoordinate: SIMD3<Float>?

    var body: some View {
        ZStack(alignment: .top) {
            ARKitCoordinateSystemView(selectedCoordinate: $selectedCoordinate)
                .ignoresSafeArea()

            if let selectedCoordinate {
                CoordinateReadout(coordinate: selectedCoordinate)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
            }
        }
        .navigationTitle("ARKit World Coordinates")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CoordinateReadout: View {

    let coordinate: SIMD3<Float>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected ARKit world point")
                .font(.headline)

            HStack(spacing: 12) {
                CoordinateValue(label: "X", value: coordinate.x, color: .red)
                CoordinateValue(label: "Y", value: coordinate.y, color: .green)
                CoordinateValue(label: "Z", value: coordinate.z, color: .blue)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct CoordinateValue: View {

    let label: String
    let value: Float
    let color: Color

    var body: some View {
        Text("\(label): \(value, specifier: "%.3f") m")
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

private struct ARKitCoordinateSystemView: UIViewControllerRepresentable {

    @Binding var selectedCoordinate: SIMD3<Float>?

    func makeUIViewController(context: Context) -> ARKitCoordinateSystemViewController {
        ARKitCoordinateSystemViewController { coordinate in
            selectedCoordinate = coordinate
        }
    }

    func updateUIViewController(
        _ uiViewController: ARKitCoordinateSystemViewController,
        context: Context
    ) {
    }
}

final class ARKitCoordinateSystemViewController: UIViewController, ARSessionDelegate {

    private let onCoordinateSelected: (SIMD3<Float>) -> Void
    private var arView: ARView!
    private var labelEntities: [Entity] = []
    private var markerAnchor: AnchorEntity?

    init(onCoordinateSelected: @escaping (SIMD3<Float>) -> Void) {
        self.onCoordinateSelected = onCoordinateSelected
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)

        arView.automaticallyConfigureSession = false
        arView.session.delegate = self

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        addCoordinateSystemVisualization()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }

    private func addCoordinateSystemVisualization() {
        let rootAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(rootAnchor)

        addCoordinatePlanes(to: rootAnchor)
        addAxisBars(to: rootAnchor)
        addDirectionLabels(to: rootAnchor)
        addOriginMarker(to: rootAnchor)
    }

    private func addCoordinatePlanes(to parent: Entity) {
        let size: Float = 0.21
        let thickness: Float = 0.002

        addBox(
            to: parent,
            name: "X axis plane",
            size: SIMD3<Float>(size, thickness, size),
            position: SIMD3<Float>(0, 0, 0),
            color: UIColor.systemRed.withAlphaComponent(0.36)
        )

        addBox(
            to: parent,
            name: "Y axis plane",
            size: SIMD3<Float>(size, size, thickness),
            position: SIMD3<Float>(0, 0, 0),
            color: UIColor.systemGreen.withAlphaComponent(0.36)
        )

        addBox(
            to: parent,
            name: "Z axis plane",
            size: SIMD3<Float>(thickness, size, size),
            position: SIMD3<Float>(0, 0, 0),
            color: UIColor.systemBlue.withAlphaComponent(0.36)
        )
    }

    private func addAxisBars(to parent: Entity) {
        let length: Float = 0.20
        let thickness: Float = 0.006

        addBox(
            to: parent,
            name: "X axis bar",
            size: SIMD3<Float>(length, thickness, thickness),
            position: SIMD3<Float>(0, 0, 0),
            color: .systemRed
        )

        addBox(
            to: parent,
            name: "Y axis bar",
            size: SIMD3<Float>(thickness, length, thickness),
            position: SIMD3<Float>(0, 0, 0),
            color: .systemGreen
        )

        addBox(
            to: parent,
            name: "Z axis bar",
            size: SIMD3<Float>(thickness, thickness, length),
            position: SIMD3<Float>(0, 0, 0),
            color: .systemBlue
        )
    }

    private func addDirectionLabels(to parent: Entity) {
        addLabel("+X", at: SIMD3<Float>(0.0325, 0, 0), color: .systemRed, to: parent)
        addLabel("-X", at: SIMD3<Float>(-0.0325, 0, 0), color: .systemRed, to: parent)
        addLabel("+Y", at: SIMD3<Float>(0, 0.052, 0), color: .systemGreen, to: parent)
        addLabel("-Y", at: SIMD3<Float>(0, -0.052, 0), color: .systemGreen, to: parent)
        addLabel("+Z", at: SIMD3<Float>(0, 0, 0.065), color: .systemBlue, to: parent)
        addLabel("-Z", at: SIMD3<Float>(0, 0, -0.065), color: .systemBlue, to: parent)
    }

    private func addOriginMarker(to parent: Entity) {
        let mesh = MeshResource.generateSphere(radius: 0.004)
        let material = SimpleMaterial(color: .white, isMetallic: false)
        let origin = ModelEntity(mesh: mesh, materials: [material])
        origin.name = "ARKit world origin"
        parent.addChild(origin)
    }

    private func addBox(
        to parent: Entity,
        name: String,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        color: UIColor
    ) {
        let mesh = MeshResource.generateBox(size: size)
        let material = SimpleMaterial(color: color, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = name
        entity.position = position
        parent.addChild(entity)
    }

    private func addLabel(
        _ text: String,
        at position: SIMD3<Float>,
        color: UIColor,
        to parent: Entity
    ) {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .boldSystemFont(ofSize: 0.0275),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        let material = SimpleMaterial(color: color, isMetallic: false)
        let label = ModelEntity(mesh: mesh, materials: [material])
        label.position = position
        label.scale = SIMD3<Float>(repeating: 1)
        labelEntities.append(label)
        parent.addChild(label)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let tapLocation = gesture.location(in: arView)

        let coordinate: SIMD3<Float>
        if let raycastResult = arView.raycast(
            from: tapLocation,
            allowing: .estimatedPlane,
            alignment: .any
        ).first {
            coordinate = raycastResult.worldTransform.translation
        } else if let cameraTransform = arView.session.currentFrame?.camera.transform {
            coordinate = fallbackPointInFrontOfCamera(cameraTransform: cameraTransform)
        } else {
            return
        }

        showMarker(at: coordinate)
        onCoordinateSelected(coordinate)
    }

    private func fallbackPointInFrontOfCamera(cameraTransform: simd_float4x4) -> SIMD3<Float> {
        let cameraPosition = cameraTransform.translation
        let forwardDirection = -SIMD3<Float>(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        )

        return cameraPosition + forwardDirection * 0.5
    }

    private func showMarker(at coordinate: SIMD3<Float>) {
        markerAnchor?.removeFromParent()

        let anchor = AnchorEntity(world: coordinate)
        let mesh = MeshResource.generateSphere(radius: 0.025)
        let material = SimpleMaterial(color: .yellow, isMetallic: false)
        let marker = ModelEntity(mesh: mesh, materials: [material])
        marker.name = "Selected ARKit world coordinate marker"

        anchor.addChild(marker)
        arView.scene.addAnchor(anchor)
        markerAnchor = anchor
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let cameraPosition = frame.camera.transform.translation

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            for labelEntity in labelEntities {
                labelEntity.look(
                    at: cameraPosition,
                    from: labelEntity.position,
                    relativeTo: nil
                )
            }
        }
    }
}

private extension simd_float4x4 {

    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

#Preview {
    NavigationStack {
        ShowARkitCoordinateSystem()
    }
}
