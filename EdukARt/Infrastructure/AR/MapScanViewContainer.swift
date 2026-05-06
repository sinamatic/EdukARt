//
//  MapScanViewContainer.swift
//  EdukARt
//
//

import ARKit
import RealityKit
import SwiftUI

struct MapScanViewContainer: UIViewRepresentable {
    @ObservedObject var session: MapScanSession

    func makeCoordinator() -> MapScanCoordinator {
        MapScanCoordinator(session: session)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

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
        context.coordinator.handleOriginPlacementRequestIfNeeded()
        context.coordinator.updateSessionStateIfNeeded()
    }
}

final class MapScanCoordinator: NSObject, ARSessionDelegate {
    var session: MapScanSession

    private weak var arView: ARView?
    private let processingQueue = DispatchQueue(label: "MapScanCoordinator.processing", qos: .userInitiated)
    private var isProcessingMeshUpdate = false
    private let floorTileSize: Float = StoredFloorMapConstants.tileSize
    private let lowestFloorTolerance: Float = 0.08
    private let meshUpdateInterval: TimeInterval = 1.0
    private var lastMeshProcessingDate = Date.distantPast
    private var handledOriginPlacementRequest = 0
    private var isSessionPaused = false

    init(session: MapScanSession) {
        self.session = session
    }

    func attach(to arView: ARView) {
        self.arView = arView
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

        if session.shouldUpdateLivePreview {
            processMeshAnchorsIfNeeded(in: arSession)
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
                }
                self.isProcessingMeshUpdate = false
            }
        }
    }

    private func computeFloorMetrics(from meshAnchors: [ARMeshAnchor]) -> (confirmedFloorArea: Float, lowestFloorHeight: Float?, floorTiles: [FloorTile]) {
        var candidateFaces: [FloorFace] = []
        var lowestFaceHeight = Float.greatestFiniteMagnitude

        for anchor in meshAnchors {
            let geometry = anchor.geometry
            let transform = anchor.transform
            let faceCount = geometry.faces.count
            let sampleStep = max(faceCount / 350, 1)

            for faceIndex in stride(from: 0, to: faceCount, by: sampleStep) {
                let classification = geometry.classificationOf(faceWithIndex: faceIndex)
                let normal = geometry.worldNormalOf(faceWithIndex: faceIndex, transform: transform)
                let upwardComponent = simd_dot(normal, SIMD3<Float>(0, 1, 0))

                guard upwardComponent > 0 else {
                    continue
                }

                let slopeAngle = acos(max(-1, min(1, upwardComponent)))
                let isFloorLike = classification == .floor || (classification == .none && slopeAngle < (.pi / 4))
                guard isFloorLike else {
                    continue
                }

                let center = geometry.worldCenterOf(faceWithIndex: faceIndex, transform: transform)
                lowestFaceHeight = min(lowestFaceHeight, center.y)
                candidateFaces.append(
                    FloorFace(center: center)
                )
            }
        }

        guard lowestFaceHeight.isFinite else {
            return (0, nil, [])
        }

        var tilesByCell: [FloorCellKey: FloorTile] = [:]

        for face in candidateFaces where face.center.y <= lowestFaceHeight + lowestFloorTolerance {
            let key = FloorCellKey(
                x: Int((face.center.x / floorTileSize).rounded()),
                z: Int((face.center.z / floorTileSize).rounded())
            )

            let tileCenter = SIMD3<Float>(
                Float(key.x) * floorTileSize,
                face.center.y,
                Float(key.z) * floorTileSize
            )

            if let existingTile = tilesByCell[key] {
                if tileCenter.y < existingTile.center.y {
                    tilesByCell[key] = FloorTile(key: key, center: tileCenter)
                }
            } else {
                tilesByCell[key] = FloorTile(key: key, center: tileCenter)
            }

        }

        let simplifiedTiles = simplifyFloorTiles(from: tilesByCell)
        let confirmedFloorArea = Float(simplifiedTiles.count) * floorTileSize * floorTileSize
        return (confirmedFloorArea, lowestFaceHeight, simplifiedTiles)
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
