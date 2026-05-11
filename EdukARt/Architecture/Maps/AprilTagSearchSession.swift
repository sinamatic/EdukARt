//
//  AprilTagSearchSession.swift
//  EdukARt
//
//

import Combine
import Foundation

@MainActor
final class AprilTagSearchSession: ObservableObject {
    @Published private(set) var detectedTagName: String?
    @Published private(set) var detectedTagNames: [String] = []
    @Published private(set) var isTagTracked = false
    @Published var statusMessage = "AprilTags werden geladen"

    var titleText: String {
        "AprilTag suchen"
    }

    var instructionText: String {
        if detectedTagNames.isEmpty == false {
            return "Erkannt: \(detectedTagNumbersText). Richte die Kamera ruhig auf die Marker, um Rahmen und Nummern stabil zu sehen."
        }

        return "Richte die Kamera auf einen ausgedruckten AprilTag. Sobald ein bekannter Tag erkannt wird, erscheint ein Rahmen mit seiner Nummer."
    }

    var statusText: String {
        if isTagTracked, detectedTagNames.isEmpty == false {
            return "Erkannt: \(detectedTagNumbersText)"
        }

        if statusMessage.isEmpty == false {
            return statusMessage
        }

        return "Suche laeuft"
    }

    var detectedTagNumbersText: String {
        detectedTagNames.map { displayNumber(for: $0) }.joined(separator: ", ")
    }

    func updateDetection(tagName: String?, isTracked: Bool) {
        updateDetection(tagNames: tagName.map { [$0] } ?? [], isTracked: isTracked)
    }

    func updateDetection(tagNames: [String], isTracked: Bool) {
        detectedTagNames = tagNames
        detectedTagName = tagNames.first
        self.isTagTracked = isTracked
        statusMessage = tagNames.isEmpty ? "Suche AprilTag" : "AprilTag erkannt"
    }

    func setSearchingMessage() {
        detectedTagName = nil
        detectedTagNames = []
        isTagTracked = false
        statusMessage = "Suche AprilTag"
    }

    func setMissingAssetsMessage() {
        detectedTagName = nil
        detectedTagNames = []
        isTagTracked = false
        statusMessage = "Keine AprilTags im Asset Catalog gefunden"
    }

    func setFailureMessage(_ message: String) {
        detectedTagName = nil
        detectedTagNames = []
        isTagTracked = false
        statusMessage = "Fehler: \(message)"
    }

    func displayNumber(for tagName: String) -> String {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trailingDigits = trimmedName.reversed().prefix(while: { $0.isNumber }).reversed()
        guard trailingDigits.isEmpty == false else {
            return tagName
        }

        return "#\(String(trailingDigits))"
    }
}
