//
//  MapScanSession.swift
//  EdukARt
//
//

import ARKit
import Combine
import Foundation

struct FloorTileSnapshot: Equatable {
    let center: SIMD3<Float>
}

@MainActor
final class MapScanSession: ObservableObject {
    enum OriginMode: Equatable {
        case aprilTag
        case manualFloorPoint
    }

    enum Phase: Equatable {
        case placingOrigin
        case scanningFloor
        case reviewBeforeSave
        case saved
    }

    @Published private(set) var phase: Phase = .placingOrigin
    @Published private(set) var mappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    @Published private(set) var confirmedFloorArea: Float = 0
    @Published private(set) var lowestFloorHeight: Float?
    @Published private(set) var hasOrigin = false
    @Published private(set) var originPlacementRequest = 0
    @Published private(set) var isSaving = false
    @Published private(set) var hasSavedCurrentScan = false
    @Published private(set) var savedMap: StoredFloorMap?
    @Published var saveMessage: String?

    let minimumRequiredAreaSquareMeters: Float = 2
    private(set) var originMode: OriginMode = .aprilTag

    private var originTransform: simd_float4x4?
    private var referenceTagName: String?
    private var currentFloorTiles: [FloorTileSnapshot] = []

    var titleText: String {
        switch phase {
        case .placingOrigin:
            originMode == .aprilTag ? "Find AprilTag #0" : "Set start point"
        case .scanningFloor:
            "Scan floor"
        case .reviewBeforeSave:
            "Review scan"
        case .saved:
            "Map ready"
        }
    }

    var instructionText: String {
        return switch phase {
        case .placingOrigin:
            if originMode == .aprilTag {
                "Point the camera at AprilTag #0. The scan starts from that point when the tag is detected."
            } else {
                "Point the camera at the floor where the map should start, then tap \"Set start point\"."
            }
        case .scanningFloor:
            if originMode == .aprilTag {
                "AprilTag #0 is set. Scan at least 2 m² of floor."
            } else {
                "The start point is set. Scan at least 2 m² of floor."
            }
        case .reviewBeforeSave:
            "The scan is paused. Check the area, enter a name, and save it."
        case .saved:
            "The map is saved and ready to use."
        }
    }

    var statusText: String {
        return switch mappingStatus {
        case .notAvailable:
            "Mapping starting"
        case .limited:
            "Mapping limited"
        case .extending:
            "Mapping expanding"
        case .mapped:
            "Mapping stable"
        @unknown default:
            "Mapping unknown"
        }
    }

    var originStatusText: String {
        switch originMode {
        case .aprilTag:
            hasOrigin ? "Tag #0 set" : "Find tag #0"
        case .manualFloorPoint:
            hasOrigin ? "Start point set" : "Start point open"
        }
    }

    var floorProgress: Double {
        let clampedArea = min(confirmedFloorArea, minimumRequiredAreaSquareMeters)
        return Double(clampedArea / minimumRequiredAreaSquareMeters)
    }

    var canFinishScan: Bool {
        phase == .scanningFloor && hasOrigin && confirmedFloorArea >= minimumRequiredAreaSquareMeters
    }

    var isReviewingScan: Bool {
        phase == .reviewBeforeSave || phase == .saved
    }

    var canSaveMap: Bool {
        phase == .reviewBeforeSave &&
        hasOrigin &&
        confirmedFloorArea >= minimumRequiredAreaSquareMeters &&
        hasSavedCurrentScan == false &&
        isSaving == false
    }

    var saveButtonTitle: String {
        if isSaving {
            return "Saving..."
        }

        if hasSavedCurrentScan {
            return "Saved"
        }

        return "Save map"
    }

    func updateMappingStatus(_ mappingStatus: ARFrame.WorldMappingStatus) {
        self.mappingStatus = mappingStatus
    }

    func configureOriginMode(_ originMode: OriginMode) {
        guard phase == .placingOrigin, hasOrigin == false else {
            return
        }

        self.originMode = originMode
    }

    func requestOriginPlacement() {
        saveMessage = nil
        originPlacementRequest += 1
    }

    func setOrigin(transform: simd_float4x4) {
        setOrigin(transform: transform, referenceTagName: nil)
    }

    func setOrigin(transform: simd_float4x4, referenceTagName: String?) {
        originTransform = transform
        self.referenceTagName = referenceTagName
        hasOrigin = true
        phase = .scanningFloor
        confirmedFloorArea = 0
        lowestFloorHeight = nil
        currentFloorTiles = []
        isSaving = false
        hasSavedCurrentScan = false
        savedMap = nil
        saveMessage = nil
    }

    func finishScan() {
        guard canFinishScan else {
            return
        }

        phase = .reviewBeforeSave
        saveMessage = "Scan paused. Name and save the map."
    }

    var shouldUpdateLivePreview: Bool {
        phase == .scanningFloor
    }

    func updateFloorMetrics(
        confirmedFloorArea: Float,
        lowestFloorHeight: Float?,
        floorTiles: [FloorTileSnapshot],
        mappingStatus: ARFrame.WorldMappingStatus
    ) {
        guard phase == .scanningFloor else {
            return
        }

        self.confirmedFloorArea = confirmedFloorArea
        self.lowestFloorHeight = lowestFloorHeight
        currentFloorTiles = floorTiles
        self.mappingStatus = mappingStatus

        guard hasOrigin else {
            return
        }
    }

    func saveMap(named name: String, into store: MapStore) {
        guard hasSavedCurrentScan == false else {
            saveMessage = "This scan has already been saved."
            return
        }

        guard let map = makeStoredMap(named: name) else {
            saveMessage = originMode == .aprilTag
                ? "Detect AprilTag #0 and scan at least 2 m² before saving."
                : "Set the start point and scan at least 2 m² before saving."
            return
        }

        isSaving = true

        do {
            try store.save(map)
            isSaving = false
            hasSavedCurrentScan = true
            savedMap = map
            phase = .saved
            saveMessage = "Saved \"\(map.name)\"."
        } catch {
            isSaving = false
            savedMap = nil
            saveMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func makeStoredMap(named name: String) -> StoredFloorMap? {
        guard phase == .reviewBeforeSave,
              hasOrigin,
              confirmedFloorArea >= minimumRequiredAreaSquareMeters,
              let originTransform else {
            return nil
        }

        let inverseOriginTransform = originTransform.inverse
        let storedTiles = currentFloorTiles.map { tile in
            let world = SIMD4<Float>(tile.center.x, tile.center.y, tile.center.z, 1)
            let local = inverseOriginTransform * world
            return StoredFloorTile(x: local.x, y: local.y, z: local.z)
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Map \(Date.now.formatted(date: .abbreviated, time: .shortened))" : trimmedName

        return StoredFloorMap(
            id: UUID(),
            name: resolvedName,
            createdAt: .now,
            minimumAreaSquareMeters: minimumRequiredAreaSquareMeters,
            floorTileSize: StoredFloorMapConstants.tileSize,
            referenceTagName: referenceTagName,
            referenceTagNumber: Self.referenceTagNumber(from: referenceTagName),
            floorTiles: storedTiles
        )
    }

    nonisolated private static func referenceTagNumber(from tagName: String?) -> Int? {
        guard let tagName else {
            return nil
        }

        let trailingDigits = tagName
            .reversed()
            .prefix(while: { $0.isNumber })
            .reversed()

        return Int(String(trailingDigits))
    }
}
