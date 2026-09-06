//
//  ShowAprilTagCoordinateSystem.swift
//  EdukARt-Rebuild
//
//  Visualizes AprilTag #0's coordinate system independently from
//  game, robot, joystick, minimap, and live AprilTag detection code.
//

import SwiftUI
import RealityKit
import ARKit
import SwiftAprilTag
import UIKit

struct ShowAprilTagCoordinateSystem: View {

    @State private var selectedCoordinate: SIMD3<Float>?
    @State private var hasPlacedCoordinateSystem = false

    var body: some View {
        ZStack(alignment: .top) {
            AprilTagCoordinateSystemView(
                selectedCoordinate: $selectedCoordinate,
                hasPlacedCoordinateSystem: $hasPlacedCoordinateSystem
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                if let selectedCoordinate {
                    AprilTagCoordinateReadout(coordinate: selectedCoordinate)
                } else if hasPlacedCoordinateSystem == false {
                    Text("Scan AprilTag #0 to place the coordinate system")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
        }
        .navigationTitle("AprilTag Coordinates")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AprilTagCoordinateReadout: View {

    let coordinate: SIMD3<Float>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected AprilTag-local point")
                .font(.headline)

            HStack(spacing: 12) {
                AprilTagCoordinateValue(label: "X", value: coordinate.x, color: .red)
                AprilTagCoordinateValue(label: "Y", value: coordinate.y, color: .green)
                AprilTagCoordinateValue(label: "Z", value: coordinate.z, color: .blue)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct AprilTagCoordinateValue: View {

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

private struct AprilTagCoordinateSystemView: UIViewControllerRepresentable {

    @Binding var selectedCoordinate: SIMD3<Float>?
    @Binding var hasPlacedCoordinateSystem: Bool

    func makeUIViewController(context: Context) -> AprilTagCoordinateSystemViewController {
        AprilTagCoordinateSystemViewController { coordinate, isPlaced in
            selectedCoordinate = coordinate
            hasPlacedCoordinateSystem = isPlaced
        }
    }

    func updateUIViewController(
        _ uiViewController: AprilTagCoordinateSystemViewController,
        context: Context
    ) {
    }
}

final class AprilTagCoordinateSystemViewController: UIViewController, ARSessionDelegate {

    private let referenceTagID = 0
    private let tagSize = 0.096
    private let maximumReprojectionError: Float = 0.5
    private let onCoordinateSelected: (SIMD3<Float>?, Bool) -> Void
    private var arView: ARView!
    private var coordinateSystemAnchor: AnchorEntity?
    private var coordinateSystemTransform: simd_float4x4?
    private var labelEntities: [Entity] = []
    private var markerAnchor: AnchorEntity?
    private var isDetecting = false
    private var frameCounter = 0

    private let detector = try! Detector(
        families: [
            .tag36h11
        ]
    )

    init(onCoordinateSelected: @escaping (SIMD3<Float>?, Bool) -> Void) {
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

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard coordinateSystemTransform != nil else {
            return
        }

        let tapLocation = gesture.location(in: arView)

        guard let worldPosition = worldPosition(for: tapLocation) else {
            return
        }

        showMarker(at: worldPosition)
        onCoordinateSelected(localCoordinate(for: worldPosition), true)
    }

    private func worldPosition(for tapLocation: CGPoint) -> SIMD3<Float>? {
        if let raycastResult = arView.raycast(
            from: tapLocation,
            allowing: .estimatedPlane,
            alignment: .any
        ).first {
            return raycastResult.worldTransform.aprilTagTranslation
        }

        guard let cameraTransform = arView.session.currentFrame?.camera.transform else {
            return nil
        }

        let cameraPosition = cameraTransform.aprilTagTranslation
        let forwardDirection = -SIMD3<Float>(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        )

        return cameraPosition + forwardDirection * 0.5
    }

    private func placeCoordinateSystem(with transform: simd_float4x4) {
        coordinateSystemAnchor?.removeFromParent()
        markerAnchor?.removeFromParent()
        labelEntities.removeAll()

        let anchor = AnchorEntity(world: transform)

        addCoordinatePlanes(to: anchor)
        addAxisBars(to: anchor)
        addDirectionLabels(to: anchor)
        addOriginMarker(to: anchor)

        arView.scene.addAnchor(anchor)
        coordinateSystemAnchor = anchor
        coordinateSystemTransform = transform
        onCoordinateSelected(nil, true)
    }

    private func localCoordinate(for worldPosition: SIMD3<Float>) -> SIMD3<Float> {
        guard let coordinateSystemTransform else {
            return .zero
        }

        let inverseTransform = simd_inverse(coordinateSystemTransform)
        let localPosition = inverseTransform * SIMD4<Float>(
            worldPosition.x,
            worldPosition.y,
            worldPosition.z,
            1
        )

        return SIMD3<Float>(localPosition.x, localPosition.y, localPosition.z)
    }

    private func addCoordinatePlanes(to parent: Entity) {
        let size: Float = 0.21
        let thickness: Float = 0.002

        addBox(
            to: parent,
            name: "AprilTag X axis plane",
            size: SIMD3<Float>(size, thickness, size),
            position: SIMD3<Float>(0, 0, 0),
            color: UIColor.systemRed.withAlphaComponent(0.36)
        )

        addBox(
            to: parent,
            name: "AprilTag Y axis plane",
            size: SIMD3<Float>(size, size, thickness),
            position: SIMD3<Float>(0, 0, 0),
            color: UIColor.systemGreen.withAlphaComponent(0.36)
        )

        addBox(
            to: parent,
            name: "AprilTag Z axis plane",
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
            name: "AprilTag X axis bar",
            size: SIMD3<Float>(length, thickness, thickness),
            position: SIMD3<Float>(0, 0, 0),
            color: .systemRed
        )

        addBox(
            to: parent,
            name: "AprilTag Y axis bar",
            size: SIMD3<Float>(thickness, length, thickness),
            position: SIMD3<Float>(0, 0, 0),
            color: .systemGreen
        )

        addBox(
            to: parent,
            name: "AprilTag Z axis bar",
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
        origin.name = "AprilTag coordinate origin"
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
        labelEntities.append(label)
        parent.addChild(label)
    }

    private func showMarker(at worldPosition: SIMD3<Float>) {
        markerAnchor?.removeFromParent()

        let anchor = AnchorEntity(world: worldPosition)
        let mesh = MeshResource.generateSphere(radius: 0.012)
        let material = SimpleMaterial(color: .yellow, isMetallic: false)
        let marker = ModelEntity(mesh: mesh, materials: [material])
        marker.name = "Selected AprilTag-local coordinate marker"

        anchor.addChild(marker)
        arView.scene.addAnchor(anchor)
        markerAnchor = anchor
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let cameraPosition = frame.camera.transform.aprilTagTranslation

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            for labelEntity in labelEntities {
                labelEntity.look(
                    at: cameraPosition,
                    from: labelEntity.position(relativeTo: nil),
                    relativeTo: nil
                )
                labelEntity.orientation *= simd_quatf(
                    angle: .pi,
                    axis: SIMD3<Float>(0, 1, 0)
                )
            }
        }

        guard coordinateSystemTransform == nil else {
            return
        }

        frameCounter += 1

        guard frameCounter % 6 == 0,
              isDetecting == false
        else {
            return
        }

        isDetecting = true
        defer {
            isDetecting = false
        }

        do {
            let detections = try detector.detect(pixelBuffer: frame.capturedImage)

            guard let referenceDetection = detections.first(where: { $0.id == referenceTagID }) else {
                return
            }

            let cameraMatrix = frame.camera.intrinsics
            let intrinsics = CameraIntrinsics(
                fx: Double(cameraMatrix.columns.0.x),
                fy: Double(cameraMatrix.columns.1.y),
                cx: Double(cameraMatrix.columns.2.x),
                cy: Double(cameraMatrix.columns.2.y)
            )

            guard let pose = referenceDetection.estimatePose(
                intrinsics: intrinsics,
                tagSize: tagSize
            ),
                  pose.reprojectionError <= maximumReprojectionError
            else {
                return
            }

            let aprilTagToARKitCamera = simd_float4x4(
                diagonal: SIMD4<Float>(1, -1, -1, 1)
            )

            let tagWorldTransform = frame.camera.transform
                * aprilTagToARKitCamera
                * pose.transform

            DispatchQueue.main.async { [weak self] in
                self?.placeCoordinateSystem(with: tagWorldTransform)
            }
        } catch {
            print("# AprilTag coordinate detection error:", error)
        }
    }
}

private extension simd_float4x4 {

    var aprilTagTranslation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

#Preview {
    NavigationStack {
        ShowAprilTagCoordinateSystem()
    }
}
