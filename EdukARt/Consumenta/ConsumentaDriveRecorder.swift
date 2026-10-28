import Foundation

final class ConsumentaDriveRecorder {
    private let minimumSampleInterval: TimeInterval = 0.1
    // Keep observing Eduard after crossing the finish line. The robot can
    // continue rolling while AprilTag detection briefly catches up.
    private let maximumPostFinishDuration: TimeInterval = 3.5

    private var mapID: UUID?
    private var mapName = ""
    private var startedAt: Date?
    private var raceDuration: TimeInterval?
    private var postFinishEndDate: Date?
    private var samples: [ConsumentaDriveSample] = []
    private var lastSampleTime: TimeInterval?
    private var lastObservedPose: RobotPose?

    func start(map: GameMap) {
        reset()
        mapID = map.id
        mapName = map.name
        startedAt = Date()
    }

    func record(pose: RobotPose) {
        guard ConsumentaConfiguration.isEnabled,
              raceDuration == nil,
              let startedAt else {
            return
        }

        lastObservedPose = pose
        let time = Date().timeIntervalSince(startedAt)
        append(pose: pose, time: time)
    }

    func finish(duration: TimeInterval) {
        guard let startedAt else {
            return
        }

        raceDuration = duration
        postFinishEndDate = Date().addingTimeInterval(maximumPostFinishDuration)

        if let lastObservedPose {
            append(
                pose: lastObservedPose,
                time: max(duration, Date().timeIntervalSince(startedAt)),
                force: true
            )
        }
    }

    func recordPostFinish(pose: RobotPose) {
        guard ConsumentaConfiguration.isEnabled,
              raceDuration != nil,
              let startedAt,
              let postFinishEndDate,
              Date() <= postFinishEndDate else {
            return
        }

        lastObservedPose = pose
        append(
            pose: pose,
            time: Date().timeIntervalSince(startedAt)
        )
    }

    func save(playerName: String) throws -> URL {
        guard let mapID,
              let startedAt,
              raceDuration != nil else {
            throw RecordingError.incompleteRecording
        }

        let exportSamples = samplesWithTrimmedStationaryTail()
        let duration = exportSamples.last?.time ?? raceDuration ?? 0

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
            samples: exportSamples
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
        raceDuration = nil
        postFinishEndDate = nil
        samples.removeAll(keepingCapacity: true)
        lastSampleTime = nil
        lastObservedPose = nil
    }

    private func append(
        pose: RobotPose,
        time: TimeInterval,
        force: Bool = false
    ) {
        if force == false,
           let lastSampleTime,
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

    private func samplesWithTrimmedStationaryTail() -> [ConsumentaDriveSample] {
        guard samples.count >= 2,
              let finalSample = samples.last else {
            return samples
        }

        var stationaryStartIndex = samples.count - 1

        while stationaryStartIndex > 0 {
            let candidate = samples[stationaryStartIndex - 1]
            let distance = hypot(candidate.x - finalSample.x, candidate.z - finalSample.z)
            let rotationDifference = abs(
                atan2(
                    sin(candidate.rotation - finalSample.rotation),
                    cos(candidate.rotation - finalSample.rotation)
                )
            )

            guard distance <= 0.015,
                  rotationDifference <= 0.035 else {
                break
            }

            stationaryStartIndex -= 1
        }

        guard stationaryStartIndex < samples.count - 1 else {
            return samples
        }

        var result = Array(samples[..<stationaryStartIndex])
        result.append(
            ConsumentaDriveSample(
                time: samples[stationaryStartIndex].time,
                x: finalSample.x,
                z: finalSample.z,
                rotation: finalSample.rotation
            )
        )
        return result
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
