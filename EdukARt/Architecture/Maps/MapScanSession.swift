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
    enum Phase: Equatable {
        case placingOrigin
        case scanningFloor
        case readyToSave
    }

    @Published private(set) var phase: Phase = .placingOrigin
    @Published private(set) var mappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    @Published private(set) var confirmedFloorArea: Float = 0
    @Published private(set) var lowestFloorHeight: Float?
    @Published private(set) var hasOrigin = false
    @Published private(set) var originPlacementRequest = 0
    @Published var saveMessage: String?

    let minimumRequiredAreaSquareMeters: Float = 6

    private var originTransform: simd_float4x4?
    private var currentFloorTiles: [FloorTileSnapshot] = []

    var titleText: String {
        switch phase {
        case .placingOrigin:
            "Startpunkt setzen"
        case .scanningFloor:
            "Bodenflaeche scannen"
        case .readyToSave:
            "Karte bereit"
        }
    }

    var instructionText: String {
        switch phase {
        case .placingOrigin:
            "Richte die Kamera auf den Boden an der Stelle, an der die Karte beginnen soll. Tippe dann auf \"Startpunkt setzen\"."
        case .scanningFloor:
            return "Der Startpunkt ist gesetzt. Scanne jetzt freie Bodenflaechen weiter. Es muessen mindestens 6 m² bestaetigt sein."
        case .readyToSave:
            return "Die Mindestflaeche ist erreicht. Wenn die Flaeche stimmt, kannst du die Karte speichern."
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
        hasOrigin ? "Startpunkt gesetzt" : "Startpunkt offen"
    }

    var floorProgress: Double {
        let clampedArea = min(confirmedFloorArea, minimumRequiredAreaSquareMeters)
        return Double(clampedArea / minimumRequiredAreaSquareMeters)
    }

    var canSaveMap: Bool {
        phase == .readyToSave && hasOrigin && confirmedFloorArea >= minimumRequiredAreaSquareMeters
    }

    func updateMappingStatus(_ mappingStatus: ARFrame.WorldMappingStatus) {
        self.mappingStatus = mappingStatus
    }

    func requestOriginPlacement() {
        saveMessage = nil
        originPlacementRequest += 1
    }

    func setOrigin(transform: simd_float4x4) {
        originTransform = transform
        hasOrigin = true
        phase = .scanningFloor
        confirmedFloorArea = 0
        lowestFloorHeight = nil
        currentFloorTiles = []
        saveMessage = nil
    }

    func updateFloorMetrics(
        confirmedFloorArea: Float,
        lowestFloorHeight: Float?,
        floorTiles: [FloorTileSnapshot],
        mappingStatus: ARFrame.WorldMappingStatus
    ) {
        self.confirmedFloorArea = confirmedFloorArea
        self.lowestFloorHeight = lowestFloorHeight
        currentFloorTiles = floorTiles
        self.mappingStatus = mappingStatus

        guard hasOrigin else {
            return
        }

        phase = confirmedFloorArea >= minimumRequiredAreaSquareMeters ? .readyToSave : .scanningFloor
    }

    func saveMap(named name: String, into store: MapStore) {
        guard let map = makeStoredMap(named: name) else {
            saveMessage = "Zum Speichern muessen zuerst der Startpunkt gesetzt und mindestens 6 m² Boden erkannt sein."
            return
        }

        do {
            try store.save(map)
            saveMessage = "Karte \"\(map.name)\" gespeichert."
        } catch {
            saveMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func makeStoredMap(named name: String) -> StoredFloorMap? {
        guard canSaveMap, let originTransform else {
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
            floorTiles: storedTiles
        )
    }
}
