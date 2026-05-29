//
//  MapScanViewContainer.swift
//  EdukARt
//
//

import ARKit
import RealityKit
import SwiftUI
import UIKit

struct MapScanViewContainer: UIViewRepresentable {
    @ObservedObject var session: MapScanSession
    let usesAprilTagOrigin: Bool

    func makeCoordinator() -> MapScanCoordinator {
        MapScanCoordinator(session: session, usesAprilTagOrigin: usesAprilTagOrigin)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        if usesAprilTagOrigin {
            context.coordinator.configureReferenceTagDetection(on: configuration)
        }

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }

        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.session.delegate = context.coordinator
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        context.coordinator.attach(to: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.session = session
        context.coordinator.usesAprilTagOrigin = usesAprilTagOrigin
        context.coordinator.handleOriginPlacementRequestIfNeeded()
        context.coordinator.updateSessionStateIfNeeded()
    }
}

final class MapScanCoordinator: NSObject, ARSessionDelegate {
    var session: MapScanSession
    var usesAprilTagOrigin: Bool

    private weak var arView: ARView?
    private let processingQueue = DispatchQueue(label: "MapScanCoordinator.processing", qos: .userInitiated)
    private let tagOverlayView = AprilTagOverlayView()
    private let floorOverlayAnchor = AnchorEntity(world: .zero)
    private var isProcessingMeshUpdate = false
    private let floorTileSize: Float = StoredFloorMapConstants.tileSize
    private let floorOverlayTileScale: Float = 0.72
    private let floorHeightTolerance: Float = 0.02
    private let meshUpdateInterval: TimeInterval = 1.0
    private var lastMeshProcessingDate = Date.distantPast
    private var handledOriginPlacementRequest = 0
    private var isSessionPaused = false
    private var isFloorOverlayAttached = false

    init(session: MapScanSession, usesAprilTagOrigin: Bool) {
        self.session = session
        self.usesAprilTagOrigin = usesAprilTagOrigin
    }

    func attach(to arView: ARView) {
        self.arView = arView

        if tagOverlayView.superview !== arView {
            tagOverlayView.translatesAutoresizingMaskIntoConstraints = false
            tagOverlayView.isUserInteractionEnabled = false
            arView.addSubview(tagOverlayView)

            NSLayoutConstraint.activate([
                tagOverlayView.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
                tagOverlayView.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
                tagOverlayView.topAnchor.constraint(equalTo: arView.topAnchor),
                tagOverlayView.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
            ])
        }

        if isFloorOverlayAttached == false {
            arView.scene.anchors.append(floorOverlayAnchor)
            isFloorOverlayAttached = true
        }
    }

    func handleOriginPlacementRequestIfNeeded() {
        guard handledOriginPlacementRequest != session.originPlacementRequest else {
            return
        }

        handledOriginPlacementRequest = session.originPlacementRequest
        placeOriginAtScreenCenter()
    }

    func updateSessionStateIfNeeded() {
        guard let arView else {
            return
        }

        if session.isReviewingScan || session.hasSavedCurrentScan {
            guard isSessionPaused == false else {
                return
            }

            arView.session.pause()
            isSessionPaused = true
            return
        }

        guard isSessionPaused else {
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        if usesAprilTagOrigin {
            configureReferenceTagDetection(on: configuration)
        }

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }

        arView.session.run(configuration, options: [])
        isSessionPaused = false
    }

    func session(_ arSession: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor [weak self] in
            self?.session.updateMappingStatus(frame.worldMappingStatus)
        }

        if usesAprilTagOrigin {
            updateReferenceTagOverlay(in: frame)
            setOriginFromReferenceTagIfNeeded(in: frame)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.tagOverlayView.clear()
            }
        }

        if session.shouldUpdateLivePreview {
            processMeshAnchorsIfNeeded(in: arSession)
        }
    }

    func configureReferenceTagDetection(on configuration: ARWorldTrackingConfiguration) {
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AprilTags", bundle: nil) else {
            return
        }

        let referenceTagImages = referenceImages.filter { $0.name == StoredFloorMapConstants.referenceTagName }
        guard referenceTagImages.isEmpty == false else {
            return
        }

        configuration.detectionImages = Set(referenceTagImages)
        configuration.maximumNumberOfTrackedImages = 1
        configuration.automaticImageScaleEstimationEnabled = false
    }

    private func setOriginFromReferenceTagIfNeeded(in frame: ARFrame) {
        guard session.hasOrigin == false else {
            return
        }

        guard let tagAnchor = frame.anchors
            .compactMap({ $0 as? ARImageAnchor })
            .first(where: { $0.referenceImage.name == StoredFloorMapConstants.referenceTagName }) else {
            return
        }

        Task { @MainActor [weak self] in
            self?.session.setOrigin(
                transform: tagAnchor.transform,
                referenceTagName: StoredFloorMapConstants.referenceTagName
            )
        }
    }

    private func updateReferenceTagOverlay(in frame: ARFrame) {
        guard let arView else {
            return
        }

        guard let tagAnchor = frame.anchors
            .compactMap({ $0 as? ARImageAnchor })
            .first(where: { $0.referenceImage.name == StoredFloorMapConstants.referenceTagName }) else {
            DispatchQueue.main.async { [weak self] in
                self?.tagOverlayView.clear()
            }
            return
        }

        let detection = AprilTagOverlayDetection(
            corners: projectedCorners(for: tagAnchor, in: arView, frame: frame),
            label: "#1"
        )
        DispatchQueue.main.async { [weak self] in
            self?.tagOverlayView.update(detections: [detection])
        }
    }

    private func projectedCorners(for anchor: ARImageAnchor, in arView: ARView, frame: ARFrame) -> [CGPoint] {
        let physicalSize = anchor.referenceImage.physicalSize
        let halfWidth = Float(physicalSize.width / 2)
        let halfHeight = Float(physicalSize.height / 2)

        let localCorners = [
            SIMD4<Float>(-halfWidth, 0, -halfHeight, 1),
            SIMD4<Float>(halfWidth, 0, -halfHeight, 1),
            SIMD4<Float>(halfWidth, 0, halfHeight, 1),
            SIMD4<Float>(-halfWidth, 0, halfHeight, 1)
        ]

        let orientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
        let viewportSize = arView.bounds.size

        return localCorners.map { localCorner in
            let worldCorner = anchor.transform * localCorner
            return frame.camera.projectPoint(
                SIMD3<Float>(worldCorner.x, worldCorner.y, worldCorner.z),
                orientation: orientation,
                viewportSize: viewportSize
            )
        }
    }

    private func placeOriginAtScreenCenter() {
        guard let arView else {
            return
        }

        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let results = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .horizontal)
        guard let firstResult = results.first else {
            Task { @MainActor [weak self] in
                self?.session.saveMessage = "Kein Boden unter dem Fadenkreuz gefunden. Richte die Kamera auf den Boden und versuche es erneut."
            }
            return
        }

        Task { @MainActor [weak self] in
            self?.session.setOrigin(transform: firstResult.worldTransform)
        }
    }

    private func processMeshAnchorsIfNeeded(in arSession: ARSession) {
        guard isProcessingMeshUpdate == false else {
            return
        }

        guard Date().timeIntervalSince(lastMeshProcessingDate) >= meshUpdateInterval else {
            return
        }

        guard let frame = arSession.currentFrame else {
            return
        }

        let meshAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        let mappingStatus = frame.worldMappingStatus

        guard meshAnchors.isEmpty == false else {
            Task { @MainActor [weak self] in
                self?.session.updateFloorMetrics(
                    confirmedFloorArea: 0,
                    lowestFloorHeight: nil,
                    floorTiles: [],
                    mappingStatus: mappingStatus
                )
                self?.renderFloorOverlay([])
            }
            return
        }

        isProcessingMeshUpdate = true
        lastMeshProcessingDate = Date()

        processingQueue.async { [weak self] in
            guard let self else {
                return
            }

            let floorMetrics = self.computeFloorMetrics(from: meshAnchors)

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                if self.session.shouldUpdateLivePreview {
                    self.session.updateFloorMetrics(
                        confirmedFloorArea: floorMetrics.confirmedFloorArea,
                        lowestFloorHeight: floorMetrics.lowestFloorHeight,
                        floorTiles: floorMetrics.floorTiles.map { FloorTileSnapshot(center: $0.center) },
                        mappingStatus: mappingStatus
                    )
                    self.renderFloorOverlay(floorMetrics.floorTiles)
                }
                self.isProcessingMeshUpdate = false
            }
        }
    }

    private func renderFloorOverlay(_ floorTiles: [FloorTile]) {
        floorOverlayAnchor.children.removeAll()

        let visualSize = floorTileSize * floorOverlayTileScale
        let material = SimpleMaterial(
            color: UIColor(red: 1, green: 0.08, blue: 0.62, alpha: 0.86),
            roughness: 0.65,
            isMetallic: false
        )

        for tile in floorTiles.prefix(900) {
            let mesh = MeshResource.generateBox(size: [visualSize, 0.003, visualSize])
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = SIMD3<Float>(
                tile.center.x,
                tile.center.y + 0.006,
                tile.center.z
            )
            floorOverlayAnchor.addChild(entity)
        }
    }

    private func computeFloorMetrics(from meshAnchors: [ARMeshAnchor]) -> (confirmedFloorArea: Float, lowestFloorHeight: Float?, floorTiles: [FloorTile]) {
        var candidateFaces: [FloorFace] = []
        var lowestFaceHeight = Float.greatestFiniteMagnitude

        for anchor in meshAnchors {
            let geometry = anchor.geometry
            let transform = anchor.transform
            let faceCount = geometry.faces.count
            let sampleStep = max(faceCount / 1400, 1)

            for faceIndex in stride(from: 0, to: faceCount, by: sampleStep) {
                let classification = geometry.classificationOf(faceWithIndex: faceIndex)
                guard classification == .floor else {
                    continue
                }

                let normal = geometry.worldNormalOf(faceWithIndex: faceIndex, transform: transform)
                let upwardComponent = simd_dot(normal, SIMD3<Float>(0, 1, 0))
                let slopeAngle = acos(max(-1, min(1, upwardComponent)))
                guard slopeAngle < (.pi / 12) else {
                    continue
                }

                let center = geometry.worldCenterOf(faceWithIndex: faceIndex, transform: transform)
                lowestFaceHeight = min(lowestFaceHeight, center.y)
                candidateFaces.append(FloorFace(center: center))
            }
        }

        guard lowestFaceHeight.isFinite,
              let floorHeight = representativeFloorHeight(from: candidateFaces) else {
            return (0, nil, [])
        }

        var cells: [FloorCellKey: FloorCellAccumulator] = [:]

        for face in candidateFaces where abs(face.center.y - floorHeight) <= floorHeightTolerance {
            let key = FloorCellKey(
                x: Int((face.center.x / floorTileSize).rounded()),
                z: Int((face.center.z / floorTileSize).rounded())
            )

            cells[key, default: FloorCellAccumulator()].add(height: face.center.y)
        }

        let floorTiles = cells.compactMap { key, cell -> FloorTile? in
            guard cell.sampleCount >= 1 else {
                return nil
            }

            return FloorTile(
                key: key,
                center: SIMD3<Float>(
                    Float(key.x) * floorTileSize,
                    cell.averageHeight,
                    Float(key.z) * floorTileSize
                )
            )
        }
        .sorted { lhs, rhs in
            lhs.key.z == rhs.key.z ? lhs.key.x < rhs.key.x : lhs.key.z < rhs.key.z
        }

        let confirmedFloorArea = Float(floorTiles.count) * floorTileSize * floorTileSize
        return (confirmedFloorArea, floorHeight, floorTiles)
    }

    private func representativeFloorHeight(from faces: [FloorFace]) -> Float? {
        let sortedHeights = faces.map(\.center.y).sorted()
        guard sortedHeights.isEmpty == false else {
            return nil
        }

        let minimumClusterSize = max(3, sortedHeights.count / 80)

        for startIndex in sortedHeights.indices {
            var endIndex = startIndex
            while endIndex + 1 < sortedHeights.count,
                  sortedHeights[endIndex + 1] - sortedHeights[startIndex] <= floorHeightTolerance {
                endIndex += 1
            }

            let clusterSize = endIndex - startIndex + 1
            guard clusterSize >= minimumClusterSize else {
                continue
            }

            let cluster = sortedHeights[startIndex...endIndex]
            return cluster.reduce(0, +) / Float(cluster.count)
        }

        return sortedHeights.first
    }

    private func simplifyFloorTiles(from tilesByCell: [FloorCellKey: FloorTile]) -> [FloorTile] {
        let rows = Dictionary(grouping: tilesByCell.values, by: { $0.key.z })
        let sortedRows = rows.keys.sorted()
        var simplifiedRows: [Int: SimplifiedRow] = [:]

        for row in sortedRows {
            guard let rowTiles = rows[row], rowTiles.isEmpty == false else {
                continue
            }

            let xValues = rowTiles.map(\.key.x).sorted()
            guard var minX = xValues.first, var maxX = xValues.last else {
                continue
            }

            if maxX - minX >= 2 {
                minX += 1
                maxX -= 1
            }

            let averageY = rowTiles.map(\.center.y).reduce(0, +) / Float(rowTiles.count)
            simplifiedRows[row] = SimplifiedRow(z: row, minX: minX, maxX: maxX, y: averageY)
        }

        for row in sortedRows {
            let neighbors = [row - 1, row, row + 1].compactMap { simplifiedRows[$0] }
            guard neighbors.isEmpty == false else {
                continue
            }

            let minXs = neighbors.map(\.minX).sorted()
            let maxXs = neighbors.map(\.maxX).sorted()
            let smoothedMinX = minXs[minXs.count / 2]
            let smoothedMaxX = maxXs[maxXs.count / 2]

            if var currentRow = simplifiedRows[row], smoothedMinX <= smoothedMaxX {
                currentRow.minX = smoothedMinX
                currentRow.maxX = smoothedMaxX
                simplifiedRows[row] = currentRow
            }
        }

        var simplifiedTiles: [FloorTile] = []

        for row in sortedRows {
            guard let simplifiedRow = simplifiedRows[row] else {
                continue
            }

            for x in simplifiedRow.minX...simplifiedRow.maxX {
                let center = SIMD3<Float>(
                    Float(x) * floorTileSize,
                    simplifiedRow.y,
                    Float(simplifiedRow.z) * floorTileSize
                )
                simplifiedTiles.append(
                    FloorTile(
                        key: FloorCellKey(x: x, z: simplifiedRow.z),
                        center: center
                    )
                )
            }
        }

        return simplifiedTiles
    }

}

private extension ARMeshGeometry {
    func classificationOf(faceWithIndex index: Int) -> ARMeshClassification {
        guard let classification else {
            return .none
        }

        let offset = classification.offset + (index * classification.stride)
        let pointer = classification.buffer.contents().advanced(by: offset)
        let rawValue = Int(pointer.assumingMemoryBound(to: UInt8.self).pointee)
        return ARMeshClassification(rawValue: rawValue) ?? .none
    }

    func vertex(at index: UInt32) -> SIMD3<Float> {
        let offset = vertices.offset + (Int(index) * vertices.stride)
        let pointer = vertices.buffer.contents().advanced(by: offset)
        return pointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
    }

    func normal(at index: UInt32) -> SIMD3<Float> {
        let offset = normals.offset + (Int(index) * normals.stride)
        let pointer = normals.buffer.contents().advanced(by: offset)
        let normal = pointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return simd_normalize(normal)
    }

    func faceIndices(at index: Int) -> (UInt32, UInt32, UInt32) {
        let bytesPerFace = faces.indexCountPerPrimitive * faces.bytesPerIndex
        let offset = index * bytesPerFace
        let pointer = faces.buffer.contents().advanced(by: offset)

        if faces.bytesPerIndex == MemoryLayout<UInt16>.size {
            let indices = pointer.assumingMemoryBound(to: UInt16.self)
            return (UInt32(indices[0]), UInt32(indices[1]), UInt32(indices[2]))
        }

        let indices = pointer.assumingMemoryBound(to: UInt32.self)
        return (indices[0], indices[1], indices[2])
    }

    func worldNormalOf(faceWithIndex index: Int, transform: simd_float4x4) -> SIMD3<Float> {
        let indices = faceIndices(at: index)
        let faceNormal = (normal(at: indices.0) + normal(at: indices.1) + normal(at: indices.2)) / 3
        let normalTransform = simd_float3x3(
            SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        )
        return simd_normalize(normalTransform * faceNormal)
    }

    func worldCenterOf(faceWithIndex index: Int, transform: simd_float4x4) -> SIMD3<Float> {
        let indices = faceIndices(at: index)
        let center = (vertex(at: indices.0) + vertex(at: indices.1) + vertex(at: indices.2)) / 3
        let localCenter = SIMD4<Float>(center.x, center.y, center.z, 1)
        let worldCenter = transform * localCenter
        return SIMD3<Float>(worldCenter.x, worldCenter.y, worldCenter.z)
    }

}

private struct FloorFace {
    let center: SIMD3<Float>
}

private struct FloorCellAccumulator {
    private(set) var heightSum: Float = 0
    private(set) var sampleCount: Int = 0

    var averageHeight: Float {
        sampleCount == 0 ? 0 : heightSum / Float(sampleCount)
    }

    mutating func add(height: Float) {
        heightSum += height
        sampleCount += 1
    }
}

private struct SimplifiedRow {
    let z: Int
    var minX: Int
    var maxX: Int
    let y: Float
}

private struct FloorTile {
    let key: FloorCellKey
    let center: SIMD3<Float>
}

private struct FloorCellKey: Hashable {
    let x: Int
    let z: Int
}
