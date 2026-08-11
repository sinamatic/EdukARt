//
//  AprilTagDetectionSession.swift
//  EdukARt
//
//

import Combine
import Foundation

@MainActor
final class AprilTagDetectionSession: ObservableObject {
    @Published private(set) var detectedTagName: String?
    @Published private(set) var detectedTagNames: [String] = []
    @Published private(set) var isTagTracked = false
    @Published var statusMessage = "Loading AprilTags"

    var titleText: String {
        "AprilTag Detection"
    }

    var instructionText: String {
        if detectedTagNames.isEmpty == false {
            return "Detected: \(detectedTagNumbersText). Keep the camera steady to track the markers."
        }

        return "Point the camera at a printed AprilTag. Known tags are highlighted with their number."
    }

    var statusText: String {
        if isTagTracked, detectedTagNames.isEmpty == false {
            return "Detected: \(detectedTagNumbersText)"
        }

        if statusMessage.isEmpty == false {
            return statusMessage
        }

        return "Searching"
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
        statusMessage = tagNames.isEmpty ? "Searching for AprilTags" : "AprilTag detected"
    }

    func setSearchingMessage() {
        detectedTagName = nil
        detectedTagNames = []
        isTagTracked = false
        statusMessage = "Searching for AprilTags"
    }

    func setMissingAssetsMessage() {
        detectedTagName = nil
        detectedTagNames = []
        isTagTracked = false
        statusMessage = "No AprilTags found in the asset catalog"
    }

    func setFailureMessage(_ message: String) {
        detectedTagName = nil
        detectedTagNames = []
        isTagTracked = false
        statusMessage = "Error: \(message)"
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
