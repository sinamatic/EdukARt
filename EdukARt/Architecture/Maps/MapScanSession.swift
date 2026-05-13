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
    @Published var saveMessage: String?

    let minimumRequiredAreaSquareMeters: Float = 2
    private(set) var originMode: OriginMode = .aprilTag

    private var originTransform: simd_float4x4?
    private var referenceTagName: String?
    private var currentFloorTiles: [FloorTileSnapshot] = []

    var titleText: String {
        switch phase {
        case .placingOrigin:
            originMode == .aprilTag ? "AprilTag #3 suchen" : "Startpunkt setzen"
        case .scanningFloor:
            "Bodenflaeche scannen"
        case .reviewBeforeSave:
            "Scan pruefen"
        case .saved:
            "Karte bereit"
        }
    }

    var instructionText: String {
        return switch phase {
        case .placingOrigin:
            if originMode == .aprilTag {
                "Richte die Kamera auf AprilTag #3. Sobald der Tag erkannt wird, startet der Umgebungsscan automatisch von diesem Punkt aus."
            } else {
                "Richte die Kamera auf den Boden an der Stelle, an der die Karte beginnen soll. Tippe dann auf \"Startpunkt setzen\"."
            }
        case .scanningFloor:
            if originMode == .aprilTag {
                "AprilTag #3 ist gesetzt. Scanne jetzt die Umgebung weiter. Es muessen mindestens 2 m² bestaetigt sein."
            } else {
                "Der Startpunkt ist gesetzt. Scanne jetzt die Umgebung weiter. Es muessen mindestens 2 m² bestaetigt sein."
            }
        case .reviewBeforeSave:
            "Der Scan ist eingefroren. Pruefe die aufgenommene Flaeche und vergebe dann einen Namen, bevor du speicherst."
        case .saved:
            "Die Mindestflaeche ist erreicht. Wenn die Flaeche stimmt, kannst du die Karte speichern."
        }
    }

    var statusText: String {
        return switch mappingStatus {
        case .notAvailable:
            "Mapping startet"
        case .limited:
            "Mapping begrenzt"
        case .extending:
            "Mapping erweitert sich"
        case .mapped:
            "Mapping stabil"
        @unknown default:
            "Mapping unbekannt"
        }
    }

    var originStatusText: String {
        switch originMode {
        case .aprilTag:
            hasOrigin ? "Tag #3 gesetzt" : "Tag #3 suchen"
        case .manualFloorPoint:
            hasOrigin ? "Startpunkt gesetzt" : "Startpunkt offen"
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
            return "Speichert..."
        }

        if hasSavedCurrentScan {
            return "Gespeichert"
        }

        return "Karte speichern"
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
        saveMessage = nil
    }

    func finishScan() {
        guard canFinishScan else {
            return
        }

        phase = .reviewBeforeSave
        saveMessage = "Scan eingefroren. Du kannst der Karte jetzt einen Namen geben und speichern."
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
            saveMessage = "Diese Aufnahme wurde bereits gespeichert."
            return
        }

        guard let map = makeStoredMap(named: name) else {
            saveMessage = originMode == .aprilTag
                ? "Zum Speichern muss zuerst AprilTag #3 erkannt und mindestens 2 m² Boden erkannt sein."
                : "Zum Speichern muss zuerst der Startpunkt gesetzt und mindestens 2 m² Boden erkannt sein."
            return
        }

        isSaving = true

        do {
            try store.save(map)
            isSaving = false
            hasSavedCurrentScan = true
            phase = .saved
            saveMessage = "Karte \"\(map.name)\" gespeichert."
        } catch {
            isSaving = false
            saveMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
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
        let resolvedName = trimmedName.isEmpty ? "Karte \(Date.now.formatted(date: .abbreviated, time: .shortened))" : trimmedName

        return StoredFloorMap(
            id: UUID(),
            name: resolvedName,
            createdAt: .now,
            minimumAreaSquareMeters: minimumRequiredAreaSquareMeters,
            floorTileSize: StoredFloorMapConstants.tileSize,
            referenceTagName: referenceTagName,
            floorTiles: storedTiles
        )
    }
}
