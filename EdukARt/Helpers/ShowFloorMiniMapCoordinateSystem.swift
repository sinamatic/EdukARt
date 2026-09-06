//
//  ShowFloorMiniMapCoordinateSystem.swift
//  EdukARt-Rebuild
//
//  Independent AR debug view for creating a floor-projected minimap from
//  scanned AprilTags. The first detected AprilTag becomes the reference origin.
//  Tags are collected first; pressing Scan Done freezes the measurements and
//  projects a stable minimap with a 10 cm grid, distance labels, and a pixel
//  conversion frame onto the floor.
//

import SwiftUI
import RealityKit
import ARKit
import SwiftAprilTag
import UIKit

struct ShowFloorMiniMapCoordinateSystem: View {

    @State private var referenceTagID: Int?
    @State private var scannedTagCount = 0
    @State private var isProjected = false
    @State private var scaleDescription = ""
    @State private var scanDoneRequest = 0

    var body: some View {
        ZStack(alignment: .top) {
            FloorMiniMapCoordinateSystemView(
                referenceTagID: $referenceTagID,
                scannedTagCount: $scannedTagCount,
                isProjected: $isProjected,
                scaleDescription: $scaleDescription,
                scanDoneRequest: $scanDoneRequest
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                if let referenceTagID {
                    Text("Reference AprilTag: #\(referenceTagID)")
                        .font(.headline)

                    Text("Scanned tags: \(scannedTagCount)")
                        .font(.subheadline)

                    if scaleDescription.isEmpty == false {
                        Text(scaleDescription)
                            .font(.system(.caption, design: .monospaced))
                    }

                    if isProjected == false {
                        Button("Scan Done") {
                            scanDoneRequest += 1
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                } else {
                    Text("Scan any AprilTag to start the floor minimap")
                        .font(.callout)
                }
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, 16)
            .padding(.horizontal, 16)
        }
        .navigationTitle("Floor MiniMap")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FloorMiniMapCoordinateSystemView: UIViewControllerRepresentable {

    @Binding var referenceTagID: Int?
    @Binding var scannedTagCount: Int
    @Binding var isProjected: Bool
    @Binding var scaleDescription: String
    @Binding var scanDoneRequest: Int

    func makeUIViewController(context: Context) -> FloorMiniMapCoordinateSystemViewController {
        FloorMiniMapCoordinateSystemViewController { referenceID, tagCount, projected, scaleText in
            referenceTagID = referenceID
            scannedTagCount = tagCount
            isProjected = projected
            scaleDescription = scaleText
        }
    }

    func updateUIViewController(
        _ uiViewController: FloorMiniMapCoordinateSystemViewController,
        context: Context
    ) {
        uiViewController.finishScanningIfNeeded(requestID: scanDoneRequest)
    }
}

final class FloorMiniMapCoordinateSystemViewController: UIViewController, ARSessionDelegate {

    private struct TagMeasurement {
        let id: Int
        let localPosition: SIMD3<Float>
    }

    private struct FinalTag {
        let id: Int
        let localPosition: SIMD3<Float>
    }

    private struct MiniMapBounds {
        let minX: Float
        let maxX: Float
        let minZ: Float
        let maxZ: Float

        var width: Float {
            maxX - minX
        }

        var depth: Float {
            maxZ - minZ
        }
    }

    private let tagSize = 0.096
    private let maximumReprojectionError: Float = 0.5
    private let gridStep: Float = 0.10
    private let minimumMapSize: Float = 0.60
    private let mapPadding: Float = 0.20
    private let designScreenPixels: Float = 360
    private let maximumDistanceLabels = 10
    private let onMiniMapUpdated: (Int?, Int, Bool, String) -> Void

    private var arView: ARView!
    private var worldAnchor: AnchorEntity?
    private var mapRoot: Entity?
    private var mapRootWorldTransform: simd_float4x4?
    private var referenceTagID: Int?
    private var measurementsByID: [Int: [SIMD3<Float>]] = [:]
    private var labelEntities: [Entity] = []
    private var isDetecting = false
    private var isProjected = false
    private var frameCounter = 0
    private var handledScanDoneRequest = 0

    private let detector = try! Detector(
        families: [
            .tag36h11
        ]
    )

    init(onMiniMapUpdated: @escaping (Int?, Int, Bool, String) -> Void) {
        self.onMiniMapUpdated = onMiniMapUpdated
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
    }

    func finishScanningIfNeeded(requestID: Int) {
        guard requestID != handledScanDoneRequest else {
            return
        }

        handledScanDoneRequest = requestID
        finishScanning()
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updateLabelOrientation(cameraTransform: frame.camera.transform)

        guard isProjected == false else {
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

        scanFrame(frame)
    }

    private func scanFrame(_ frame: ARFrame) {
        do {
            let detections = try detector.detect(pixelBuffer: frame.capturedImage)

            guard detections.isEmpty == false else {
                return
            }

            let cameraMatrix = frame.camera.intrinsics
            let intrinsics = CameraIntrinsics(
                fx: Double(cameraMatrix.columns.0.x),
                fy: Double(cameraMatrix.columns.1.y),
                cx: Double(cameraMatrix.columns.2.x),
                cy: Double(cameraMatrix.columns.2.y)
            )

            let measuredTransforms = detections.compactMap { detection -> (id: Int, transform: simd_float4x4)? in
                guard let pose = detection.estimatePose(
                    intrinsics: intrinsics,
                    tagSize: tagSize
                ),
                      pose.reprojectionError <= maximumReprojectionError
                else {
                    return nil
                }

                let aprilTagToARKitCamera = simd_float4x4(
                    diagonal: SIMD4<Float>(1, -1, -1, 1)
                )

                let worldTransform = frame.camera.transform
                    * aprilTagToARKitCamera
                    * pose.transform

                return (detection.id, worldTransform)
            }

            guard measuredTransforms.isEmpty == false else {
                return
            }

            if mapRootWorldTransform == nil {
                let reference = measuredTransforms[0]
                referenceTagID = reference.id
                mapRootWorldTransform = makeMapRootTransform(from: reference.transform)
            }

            guard let mapRootWorldTransform else {
                return
            }

            let inverseRoot = simd_inverse(mapRootWorldTransform)
            let measurements = measuredTransforms.map { tag in
                let worldPosition = tag.transform.floorMiniMapTranslation
                let local = inverseRoot * SIMD4<Float>(
                    worldPosition.x,
                    worldPosition.y,
                    worldPosition.z,
                    1
                )

                return TagMeasurement(
                    id: tag.id,
                    localPosition: SIMD3<Float>(local.x, local.y, local.z)
                )
            }

            store(measurements)

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                self.onMiniMapUpdated(
                    self.referenceTagID,
                    self.measurementsByID.count,
                    false,
                    self.scanProgressDescription()
                )
            }
        } catch {
            print("# Floor minimap scan error:", error)
        }
    }

    private func store(_ measurements: [TagMeasurement]) {
        for measurement in measurements {
            measurementsByID[measurement.id, default: []].append(measurement.localPosition)

            if let count = measurementsByID[measurement.id]?.count,
               count > 40 {
                measurementsByID[measurement.id]?.removeFirst(count - 40)
            }
        }
    }

    private func finishScanning() {
        guard let referenceTagID,
              let mapRootWorldTransform,
              measurementsByID.isEmpty == false,
              isProjected == false
        else {
            return
        }

        let finalTags = measurementsByID
            .map { id, positions in
                FinalTag(
                    id: id,
                    localPosition: averagePosition(positions)
                )
            }
            .sorted { first, second in
                if first.id == referenceTagID {
                    return true
                }

                if second.id == referenceTagID {
                    return false
                }

                return first.id < second.id
            }

        let anchor = AnchorEntity(world: .zero)
        let root = Entity()
        root.name = "FloorMiniMapRoot"
        root.transform.matrix = mapRootWorldTransform

        anchor.addChild(root)
        arView.scene.addAnchor(anchor)

        worldAnchor = anchor
        mapRoot = root
        isProjected = true

        let scaleText = renderFinalMiniMap(finalTags: finalTags, in: root)

        onMiniMapUpdated(
            referenceTagID,
            finalTags.count,
            true,
            scaleText
        )
    }

    private func averagePosition(_ positions: [SIMD3<Float>]) -> SIMD3<Float> {
        guard positions.isEmpty == false else {
            return .zero
        }

        var sum = SIMD3<Float>.zero

        for position in positions {
            sum += position
        }

        return sum / Float(positions.count)
    }

    private func makeMapRootTransform(from tagWorldTransform: simd_float4x4) -> simd_float4x4 {
        let position = tagWorldTransform.floorMiniMapTranslation

        var xAxis = SIMD3<Float>(
            tagWorldTransform.columns.0.x,
            0,
            tagWorldTransform.columns.0.z
        )

        if simd_length(xAxis) <= 0.001 {
            xAxis = SIMD3<Float>(1, 0, 0)
        } else {
            xAxis = simd_normalize(xAxis)
        }

        let yAxis = SIMD3<Float>(0, 1, 0)
        let zAxis = simd_normalize(simd_cross(xAxis, yAxis))

        return simd_float4x4(
            columns: (
                SIMD4<Float>(xAxis.x, xAxis.y, xAxis.z, 0),
                SIMD4<Float>(yAxis.x, yAxis.y, yAxis.z, 0),
                SIMD4<Float>(zAxis.x, zAxis.y, zAxis.z, 0),
                SIMD4<Float>(position.x, position.y, position.z, 1)
            )
        )
    }

    private func renderFinalMiniMap(finalTags: [FinalTag], in mapRoot: Entity) -> String {
        labelEntities.removeAll()
        mapRoot.children.removeAll()

        let bounds = makeBounds(for: finalTags)
        let pixelsPerMeter = designScreenPixels / max(bounds.width, bounds.depth)
        let scaleText = String(
            format: "%.2f m x %.2f m -> %.0f px x %.0f px | 10 cm = %.0f px",
            bounds.width,
            bounds.depth,
            bounds.width * pixelsPerMeter,
            bounds.depth * pixelsPerMeter,
            gridStep * pixelsPerMeter
        )

        addGrid(to: mapRoot, bounds: bounds)
        addFrame(to: mapRoot, bounds: bounds, pixelsPerMeter: pixelsPerMeter)
        addCoordinateAxes(to: mapRoot, bounds: bounds)
        addTagMarkers(to: mapRoot, finalTags: finalTags)
        addDistanceLabels(to: mapRoot, finalTags: finalTags)

        return scaleText
    }

    private func makeBounds(for tags: [FinalTag]) -> MiniMapBounds {
        var minX: Float = -minimumMapSize / 2
        var maxX: Float = minimumMapSize / 2
        var minZ: Float = -minimumMapSize / 2
        var maxZ: Float = minimumMapSize / 2

        for tag in tags {
            minX = min(minX, tag.localPosition.x)
            maxX = max(maxX, tag.localPosition.x)
            minZ = min(minZ, tag.localPosition.z)
            maxZ = max(maxZ, tag.localPosition.z)
        }

        minX = floor((minX - mapPadding) / gridStep) * gridStep
        maxX = ceil((maxX + mapPadding) / gridStep) * gridStep
        minZ = floor((minZ - mapPadding) / gridStep) * gridStep
        maxZ = ceil((maxZ + mapPadding) / gridStep) * gridStep

        return MiniMapBounds(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ)
    }

    private func scanProgressDescription() -> String {
        let sortedIDs = measurementsByID.keys.sorted()
        let idText = sortedIDs.map { "#\($0)" }.joined(separator: ", ")

        guard idText.isEmpty == false else {
            return "Scanning..."
        }

        return "Scanning: \(idText)"
    }

    private func addGrid(to parent: Entity, bounds: MiniMapBounds) {
        let lineThickness: Float = 0.002
        let y: Float = 0.002

        var x = bounds.minX
        while x <= bounds.maxX + 0.001 {
            addBox(
                to: parent,
                name: "10 cm grid z-line",
                size: SIMD3<Float>(lineThickness, lineThickness, bounds.depth),
                position: SIMD3<Float>(x, y, bounds.minZ + bounds.depth / 2),
                color: UIColor.white.withAlphaComponent(0.24)
            )
            x += gridStep
        }

        var z = bounds.minZ
        while z <= bounds.maxZ + 0.001 {
            addBox(
                to: parent,
                name: "10 cm grid x-line",
                size: SIMD3<Float>(bounds.width, lineThickness, lineThickness),
                position: SIMD3<Float>(bounds.minX + bounds.width / 2, y, z),
                color: UIColor.white.withAlphaComponent(0.24)
            )
            z += gridStep
        }
    }

    private func addFrame(to parent: Entity, bounds: MiniMapBounds, pixelsPerMeter: Float) {
        let thickness: Float = 0.006
        let y: Float = 0.006
        let centerX = bounds.minX + bounds.width / 2
        let centerZ = bounds.minZ + bounds.depth / 2

        addBox(
            to: parent,
            name: "minimap top frame",
            size: SIMD3<Float>(bounds.width, thickness, thickness),
            position: SIMD3<Float>(centerX, y, bounds.maxZ),
            color: .white
        )
        addBox(
            to: parent,
            name: "minimap bottom frame",
            size: SIMD3<Float>(bounds.width, thickness, thickness),
            position: SIMD3<Float>(centerX, y, bounds.minZ),
            color: .white
        )
        addBox(
            to: parent,
            name: "minimap left frame",
            size: SIMD3<Float>(thickness, thickness, bounds.depth),
            position: SIMD3<Float>(bounds.minX, y, centerZ),
            color: .white
        )
        addBox(
            to: parent,
            name: "minimap right frame",
            size: SIMD3<Float>(thickness, thickness, bounds.depth),
            position: SIMD3<Float>(bounds.maxX, y, centerZ),
            color: .white
        )

        addLabel(
            String(format: "width %.2f m = %.0f px", bounds.width, bounds.width * pixelsPerMeter),
            at: SIMD3<Float>(centerX, 0.045, bounds.maxZ + 0.055),
            color: .white,
            to: parent
        )

        addLabel(
            String(format: "height %.2f m = %.0f px", bounds.depth, bounds.depth * pixelsPerMeter),
            at: SIMD3<Float>(bounds.maxX + 0.055, 0.045, centerZ),
            color: .white,
            to: parent
        )

        addLabel(
            String(format: "10 cm = %.0f px", gridStep * pixelsPerMeter),
            at: SIMD3<Float>(bounds.minX, 0.045, bounds.minZ - 0.055),
            color: .white,
            to: parent
        )
    }

    private func addCoordinateAxes(to parent: Entity, bounds: MiniMapBounds) {
        let y: Float = 0.010
        let thickness: Float = 0.004

        if bounds.minZ <= 0, bounds.maxZ >= 0 {
            addBox(
                to: parent,
                name: "minimap x axis",
                size: SIMD3<Float>(bounds.width, thickness, thickness),
                position: SIMD3<Float>(bounds.minX + bounds.width / 2, y, 0),
                color: .systemRed
            )
        }

        if bounds.minX <= 0, bounds.maxX >= 0 {
            addBox(
                to: parent,
                name: "minimap z axis",
                size: SIMD3<Float>(thickness, thickness, bounds.depth),
                position: SIMD3<Float>(0, y, bounds.minZ + bounds.depth / 2),
                color: .systemBlue
            )
        }

        addLabel("+X", at: SIMD3<Float>(min(bounds.maxX, 0.20), 0.045, 0), color: .systemRed, to: parent)
        addLabel("+Z", at: SIMD3<Float>(0, 0.045, min(bounds.maxZ, 0.20)), color: .systemBlue, to: parent)
    }

    private func addTagMarkers(to parent: Entity, finalTags: [FinalTag]) {
        for tag in finalTags {
            let isReference = tag.id == referenceTagID
            let color: UIColor = isReference ? .systemGreen : .systemYellow
            let radius: Float = isReference ? 0.018 : 0.014

            let mesh = MeshResource.generateCylinder(height: 0.006, radius: radius)
            let material = SimpleMaterial(color: color, isMetallic: false)
            let marker = ModelEntity(mesh: mesh, materials: [material])
            marker.name = "AprilTag #\(tag.id) minimap marker"
            marker.position = SIMD3<Float>(tag.localPosition.x, 0.018, tag.localPosition.z)
            parent.addChild(marker)

            addLabel(
                "#\(tag.id)",
                at: SIMD3<Float>(tag.localPosition.x, 0.055, tag.localPosition.z + 0.035),
                color: color,
                to: parent
            )
        }
    }

    private func addDistanceLabels(to parent: Entity, finalTags: [FinalTag]) {
        guard finalTags.count >= 2 else {
            return
        }

        for pair in tagPairs(from: finalTags).prefix(maximumDistanceLabels) {
            let start = pair.0.localPosition
            let end = pair.1.localPosition
            let delta = SIMD3<Float>(end.x - start.x, 0, end.z - start.z)
            let distance = simd_length(delta)
            let midpoint = SIMD3<Float>(
                (start.x + end.x) / 2,
                0.030,
                (start.z + end.z) / 2
            )

            addDistanceLine(
                to: parent,
                start: SIMD3<Float>(start.x, 0.014, start.z),
                end: SIMD3<Float>(end.x, 0.014, end.z)
            )

            addLabel(
                String(format: "%.2f m", distance),
                at: midpoint,
                color: .white,
                to: parent
            )
        }
    }

    private func tagPairs(from tags: [FinalTag]) -> [(FinalTag, FinalTag)] {
        var pairs: [(FinalTag, FinalTag)] = []

        for startIndex in tags.indices {
            for endIndex in tags.indices where endIndex > startIndex {
                pairs.append((tags[startIndex], tags[endIndex]))
            }
        }

        return pairs.sorted { first, second in
            let firstDistance = simd_distance(first.0.localPosition, first.1.localPosition)
            let secondDistance = simd_distance(second.0.localPosition, second.1.localPosition)
            return firstDistance < secondDistance
        }
    }

    private func addDistanceLine(to parent: Entity, start: SIMD3<Float>, end: SIMD3<Float>) {
        let delta = SIMD3<Float>(end.x - start.x, 0, end.z - start.z)
        let length = simd_length(delta)

        guard length > 0.001 else {
            return
        }

        let mesh = MeshResource.generateBox(size: SIMD3<Float>(length, 0.003, 0.003))
        let material = SimpleMaterial(color: UIColor.white.withAlphaComponent(0.75), isMetallic: false)
        let line = ModelEntity(mesh: mesh, materials: [material])
        line.name = "AprilTag distance line"
        line.position = SIMD3<Float>((start.x + end.x) / 2, start.y, (start.z + end.z) / 2)
        line.orientation = simd_quatf(angle: atan2(-delta.z, delta.x), axis: SIMD3<Float>(0, 1, 0))
        parent.addChild(line)
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
            font: .boldSystemFont(ofSize: 0.025),
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

    private func updateLabelOrientation(cameraTransform: simd_float4x4) {
        let cameraPosition = cameraTransform.floorMiniMapTranslation

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
    }
}

private extension simd_float4x4 {

    var floorMiniMapTranslation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

#Preview {
    NavigationStack {
        ShowFloorMiniMapCoordinateSystem()
    }
}
