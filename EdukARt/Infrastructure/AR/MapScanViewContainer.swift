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
        arView.environment.sceneUnderstanding.options.insert(.collision)
        arView.environment.sceneUnderstanding.options.insert(.physics)
        arView.session.delegate = context.coordinator
        arView.session.run(configuration)

        context.coordinator.attach(to: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.session = session
    }
}

final class MapScanCoordinator: NSObject, ARSessionDelegate {
    var session: MapScanSession

    private weak var arView: ARView?
    private let processingQueue = DispatchQueue(label: "MapScanCoordinator.processing", qos: .userInitiated)
    private var isProcessingMeshUpdate = false
    private let floorOverlayAnchor = AnchorEntity(world: .zero)
    private var floorTileEntities: [FloorCellKey: ModelEntity] = [:]
    private let floorTileSize: Float = 0.16
    private let lowestFloorTolerance: Float = 0.08

    init(session: MapScanSession) {
        self.session = session
    }

    func attach(to arView: ARView) {
        self.arView = arView
        arView.scene.anchors.append(floorOverlayAnchor)
    }

    func session(_ arSession: ARSession, didUpdate frame: ARFrame) {
        let yaw = cameraYaw(from: frame.camera.transform)

        Task { @MainActor [weak self] in
            self?.session.recordCameraYaw(yaw, mappingStatus: frame.worldMappingStatus)
        }
    }

    func session(_ arSession: ARSession, didAdd anchors: [ARAnchor]) {
        processMeshAnchorsIfNeeded(in: arSession)
    }

    func session(_ arSession: ARSession, didUpdate anchors: [ARAnchor]) {
        processMeshAnchorsIfNeeded(in: arSession)
    }

    func session(_ arSession: ARSession, didRemove anchors: [ARAnchor]) {
        processMeshAnchorsIfNeeded(in: arSession)
    }

    private func processMeshAnchorsIfNeeded(in arSession: ARSession) {
        guard isProcessingMeshUpdate == false else {
            return
        }

        guard let frame = arSession.currentFrame else {
            return
        }

        let meshAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        let mappingStatus = frame.worldMappingStatus

        guard meshAnchors.isEmpty == false else {
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                self.session.updateWallMetrics(
                    scannedWallArea: 0,
                    estimatedRoomArea: 0,
                    coverageProgress: self.session.wallCoverageProgress,
                    mappingStatus: mappingStatus
                )
                self.session.updateFloorMetrics(
                    confirmedFloorArea: 0,
                    estimatedRoomArea: 0,
                    lowestFloorHeight: nil,
                    mappingStatus: mappingStatus
                )
                self.renderFloorTiles([])
            }
            return
        }

        isProcessingMeshUpdate = true

        processingQueue.async { [weak self] in
            guard let self else {
                return
            }

            let wallMetrics = self.computeWallMetrics(from: meshAnchors)
            let floorMetrics = self.computeFloorMetrics(from: meshAnchors)

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                self.session.updateWallMetrics(
                    scannedWallArea: wallMetrics.wallArea,
                    estimatedRoomArea: wallMetrics.roomAreaEstimate,
                    coverageProgress: self.session.wallCoverageProgress,
                    mappingStatus: mappingStatus
                )
                self.session.updateFloorMetrics(
                    confirmedFloorArea: floorMetrics.confirmedFloorArea,
                    estimatedRoomArea: wallMetrics.roomAreaEstimate,
                    lowestFloorHeight: floorMetrics.lowestFloorHeight,
                    mappingStatus: mappingStatus
                )
                self.renderFloorTiles(floorMetrics.floorTiles)
                self.isProcessingMeshUpdate = false
            }
        }
    }

    private func computeWallMetrics(from meshAnchors: [ARMeshAnchor]) -> (wallArea: Float, roomAreaEstimate: Float) {
        var totalWallArea: Float = 0
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude

        for anchor in meshAnchors {
            let geometry = anchor.geometry
            let transform = anchor.transform

            for faceIndex in 0..<geometry.faces.count {
                let classification = geometry.classificationOf(faceWithIndex: faceIndex)
                guard classification == .wall || classification == .door || classification == .window else {
                    continue
                }

                totalWallArea += geometry.areaOf(faceWithIndex: faceIndex)

                let center = geometry.worldCenterOf(faceWithIndex: faceIndex, transform: transform)
                minX = min(minX, center.x)
                maxX = max(maxX, center.x)
                minZ = min(minZ, center.z)
                maxZ = max(maxZ, center.z)
            }
        }

        let roomAreaEstimate: Float
        if minX.isFinite, maxX.isFinite, minZ.isFinite, maxZ.isFinite {
            roomAreaEstimate = max((maxX - minX) * (maxZ - minZ), 0)
        } else {
            roomAreaEstimate = 0
        }

        return (totalWallArea, roomAreaEstimate)
    }

    private func computeFloorMetrics(from meshAnchors: [ARMeshAnchor]) -> (confirmedFloorArea: Float, lowestFloorHeight: Float?, floorTiles: [FloorTile]) {
        var candidateFaces: [FloorFace] = []
        var lowestFaceHeight = Float.greatestFiniteMagnitude

        for anchor in meshAnchors {
            let geometry = anchor.geometry
            let transform = anchor.transform

            for faceIndex in 0..<geometry.faces.count {
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
                candidateFaces.append(FloorFace(center: center))
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

        let confirmedFloorArea = Float(tilesByCell.count) * floorTileSize * floorTileSize
        return (confirmedFloorArea, lowestFaceHeight, Array(tilesByCell.values))
    }

    private func cameraYaw(from transform: simd_float4x4) -> Float {
        let forward = SIMD3<Float>(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
        return atan2(forward.x, forward.z)
    }

    @MainActor
    private func renderFloorTiles(_ tiles: [FloorTile]) {
        let activeKeys = Set(tiles.map(\.key))

        let removedKeys = floorTileEntities.keys.filter { activeKeys.contains($0) == false }
        for key in removedKeys {
            floorTileEntities[key]?.removeFromParent()
            floorTileEntities.removeValue(forKey: key)
        }

        let material = SimpleMaterial(
            color: UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 0.94),
            roughness: 1,
            isMetallic: false
        )

        for tile in tiles {
            if let entity = floorTileEntities[tile.key] {
                entity.position = tile.center + SIMD3<Float>(0, 0.002, 0)
                continue
            }

            let mesh = MeshResource.generateBox(size: [floorTileSize, 0.004, floorTileSize])
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = tile.center + SIMD3<Float>(0, 0.002, 0)
            floorOverlayAnchor.addChild(entity)
            floorTileEntities[tile.key] = entity
        }
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

    func areaOf(faceWithIndex index: Int) -> Float {
        let indices = faceIndices(at: index)
        let a = vertex(at: indices.0)
        let b = vertex(at: indices.1)
        let c = vertex(at: indices.2)
        return simd_length(simd_cross(b - a, c - a)) * 0.5
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

private struct FloorTile {
    let key: FloorCellKey
    let center: SIMD3<Float>
}

private struct FloorCellKey: Hashable {
    let x: Int
    let z: Int
}
