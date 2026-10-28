import Foundation

final class ConsumentaDriveRecorder {
    private let minimumSampleInterval: TimeInterval = 0.1

    private var mapID: UUID?
    private var mapName = ""
    private var startedAt: Date?
    private var duration: TimeInterval?
    private var samples: [ConsumentaDriveSample] = []
    private var lastSampleTime: TimeInterval?

    func start(map: GameMap) {
        reset()
        mapID = map.id
        mapName = map.name
        startedAt = Date()
    }

    func record(pose: RobotPose) {
        guard ConsumentaConfiguration.isEnabled,
              duration == nil,
              let startedAt else {
            return
        }

        let time = Date().timeIntervalSince(startedAt)

        if let lastSampleTime,
           time - lastSampleTime < minimumSampleInterval {
            return
        }

        samples.append(
            ConsumentaDriveSample(
                time: time,
                x: pose.position.x,
                z: pose.position.z,
                rotation: pose.rotation
            )
        )
        lastSampleTime = time
    }

    func finish(duration: TimeInterval) {
        guard startedAt != nil else {
            return
        }

        self.duration = duration
    }

    func save(playerName: String) throws -> URL {
        guard let mapID,
              let startedAt,
              let duration else {
            throw RecordingError.incompleteRecording
        }

        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Player" : trimmedName
        let recording = ConsumentaDriveRecording(
            formatVersion: 1,
            id: UUID(),
            mapID: mapID,
            mapName: mapName,
            playerName: resolvedName,
            startedAt: startedAt,
            duration: duration,
            samples: samples
        )

        let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("ConsumentaDrives", isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let fileName = "EdukARt-Fahrt_\(safeFileName(mapName))_\(safeFileName(resolvedName))_\(recording.id.uuidString).json"
        let fileURL = directory.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(recording).write(to: fileURL, options: .atomic)
        return fileURL
    }

    func reset() {
        mapID = nil
        mapName = ""
        startedAt = nil
        duration = nil
        samples.removeAll(keepingCapacity: true)
        lastSampleTime = nil
    }

    private func safeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        return String(sanitized).prefix(40).description
    }

    private enum RecordingError: Error {
        case incompleteRecording
    }
}
