//
//  MapScanSession.swift
//  EdukARt
//
//

import ARKit
import Combine
import Foundation

@MainActor
final class MapScanSession: ObservableObject {
    enum Phase: Equatable {
        case wallScan
        case floorScan
        case readyToSave
    }

    @Published private(set) var phase: Phase = .wallScan
    @Published private(set) var mappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    @Published private(set) var wallCoverageProgress: Double = 0
    @Published private(set) var scannedWallArea: Float = 0
    @Published private(set) var estimatedRoomArea: Float = 0
    @Published private(set) var floorCoverageProgress: Double = 0
    @Published private(set) var confirmedFloorArea: Float = 0
    @Published private(set) var lowestFloorHeight: Float?
    @Published var saveMessage: String?

    private let yawSectorCount = 12
    private let requiredWallCoverageProgress = 0.92
    private let requiredFloorCoverageRatio = 0.82
    private var seenYawSectors = Set<Int>()

    var titleText: String {
        switch phase {
        case .wallScan:
            "Raum waende scannen"
        case .floorScan:
            "Boden bestaetigen"
        case .readyToSave:
            "Karte bereit"
        }
    }

    var instructionText: String {
        switch phase {
        case .wallScan:
            "Scanne zuerst nur die Waende des geschlossenen Raums. Richte die Kamera rundum auf Waende, Ecken, Tueren und Uebergaenge."
        case .floorScan:
            "Scanne jetzt den gesamten Boden. Es zaehlt nur die tiefste Flaeche im Raum. Starte nicht auf Sofa, Tisch oder anderen erhoehten Flaechen."
        case .readyToSave:
            "Der dunkle Bodenbelag deckt den Raum ausreichend ab. Pruefe die Flaeche und speichere danach die Karte."
        }
    }

    var statusText: String {
        switch mappingStatus {
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

    var canContinueToFloorScan: Bool {
        wallCoverageProgress >= requiredWallCoverageProgress &&
        estimatedRoomArea > 0.5 &&
        (mappingStatus == .extending || mappingStatus == .mapped)
    }

    var canSaveMap: Bool {
        phase == .readyToSave
    }

    func updateWallMetrics(
        scannedWallArea: Float,
        estimatedRoomArea: Float,
        coverageProgress: Double,
        mappingStatus: ARFrame.WorldMappingStatus
    ) {
        self.scannedWallArea = scannedWallArea
        self.estimatedRoomArea = estimatedRoomArea
        wallCoverageProgress = coverageProgress
        self.mappingStatus = mappingStatus
    }

    func updateFloorMetrics(
        confirmedFloorArea: Float,
        estimatedRoomArea: Float,
        lowestFloorHeight: Float?,
        mappingStatus: ARFrame.WorldMappingStatus
    ) {
        self.confirmedFloorArea = confirmedFloorArea
        self.estimatedRoomArea = max(self.estimatedRoomArea, estimatedRoomArea)
        self.lowestFloorHeight = lowestFloorHeight
        self.mappingStatus = mappingStatus

        let denominator = max(self.estimatedRoomArea, 0.01)
        let ratio = min(Double(confirmedFloorArea / denominator), 1)
        floorCoverageProgress = ratio

        if ratio >= requiredFloorCoverageRatio &&
            (mappingStatus == .extending || mappingStatus == .mapped) {
            phase = .readyToSave
        }
    }

    func recordCameraYaw(_ yaw: Float, mappingStatus: ARFrame.WorldMappingStatus) {
        self.mappingStatus = mappingStatus

        guard phase == .wallScan else {
            return
        }

        let normalizedYaw = yaw >= 0 ? yaw : yaw + (.pi * 2)
        let sectorWidth = (Float.pi * 2) / Float(yawSectorCount)
        let sector = min(Int(normalizedYaw / sectorWidth), yawSectorCount - 1)
        seenYawSectors.insert(sector)
        wallCoverageProgress = Double(seenYawSectors.count) / Double(yawSectorCount)
    }

    func continueToFloorScan() {
        phase = .floorScan
        confirmedFloorArea = 0
        floorCoverageProgress = 0
        lowestFloorHeight = nil
        saveMessage = nil
    }

    func showSavePlaceholder() {
        saveMessage = "Der echte Speicherschritt folgt als naechstes. Der Button erscheint jetzt erst, wenn der Boden plausibel vollstaendig erkannt ist."
    }
}
