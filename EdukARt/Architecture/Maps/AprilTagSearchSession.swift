//
//  AprilTagSearchSession.swift
//  EdukARt
//
//

import Foundation

@MainActor
final class AprilTagSearchSession: ObservableObject {
    @Published private(set) var detectedTagName: String?
    @Published private(set) var isTagTracked = false
    @Published var statusMessage = "AprilTags werden geladen"

    var titleText: String {
        "AprilTag suchen"
    }

    var instructionText: String {
        if let detectedTagName {
            return "Der AprilTag \(displayNumber(for: detectedTagName)) wurde erkannt. Richte die Kamera ruhig auf den Marker, um Rahmen und Nummer stabil zu sehen."
        }

        return "Richte die Kamera auf einen ausgedruckten AprilTag. Sobald ein bekannter Tag erkannt wird, erscheint ein Rahmen mit seiner Nummer."
    }

    var statusText: String {
        if let detectedTagName, isTagTracked {
            return "Erkannt: \(displayNumber(for: detectedTagName))"
        }

        if statusMessage.isEmpty == false {
            return statusMessage
        }

        return "Suche laeuft"
    }

    func updateDetection(tagName: String?, isTracked: Bool) {
        detectedTagName = tagName
        isTagTracked = isTracked

        if let tagName, isTracked {
            statusMessage = "AprilTag erkannt"
        } else {
            statusMessage = "Suche AprilTag"
        }
    }

    func setMissingAssetsMessage() {
        detectedTagName = nil
        isTagTracked = false
        statusMessage = "Keine AprilTags im Asset Catalog gefunden"
    }

    func displayNumber(for tagName: String) -> String {
        guard let trailingNumber = tagName.split(separator: "-").last, trailingNumber.isEmpty == false else {
            return tagName
        }

        return "#\(trailingNumber)"
    }
}
