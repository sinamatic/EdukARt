import Foundation

final class ConsumentaDriveRecorder {
    private let minimumSampleInterval: TimeInterval = 0.2
    private let maximumPlausibleSpeed: Float = 0.75
    private let positionTolerance: Float = 0.06
    // AprilTag pose estimation can occasionally return the equally valid
    // 180-degree solution. Eduard cannot rotate 90 degrees between two 5 Hz
    // samples, so keep the equivalent heading nearest to the previous sample.
    private let aprilTagFlipThreshold: Float = 1.2
    // Keep observing Eduard after crossing the finish line. The robot can
    // continue rolling while AprilTag detection briefly catches up.
    private let maximumPostFinishDuration: TimeInterval = 3.5

    private var mapID: UUID?
    private var mapName = ""
    private var startedAt: Date?
    private var raceDuration: TimeInterval?
    private var postFinishEndDate: Date?
    private var samples: [ConsumentaDriveSample] = []
    private var initialCoins: [ConsumentaRecordedCoin] = []
    private var events: [ConsumentaGhostEvent] = []
    private var lastSampleTime: TimeInterval?
    private var lastObservedPose: RobotPose?

    func start(map: GameMap, coins: [GameCoin]) {
        reset()
        mapID = map.id
        mapName = map.name
        startedAt = Date()
        initialCoins = coins.map {
            ConsumentaRecordedCoin(
                id: $0.id,
                x: $0.position.x,
                z: $0.position.y
            )
        }
    }

    func recordCoinCollected(_ coin: GameCoin) {
        recordEvent(
            kind: .coinCollected,
            objectID: coin.id,
            objectType: nil,
            x: coin.position.x,
            z: coin.position.y
        )
    }

    func recordObjectEvent(
        kind: ConsumentaGhostEvent.Kind,
        object: PlacedMapObject
    ) {
        recordEvent(
            kind: kind,
            objectID: object.id,
            objectType: object.type,
            x: object.x,
            z: object.z
        )
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

    func save(
        playerName: String,
        recordingID: UUID,
        eduardType: ConsumentaEduardType
    ) throws -> URL {
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
            formatVersion: 3,
            id: recordingID,
            mapID: mapID,
            mapName: mapName,
            playerName: resolvedName,
            eduardType: eduardType,
            startedAt: startedAt,
            duration: duration,
            samples: exportSamples,
            initialCoins: initialCoins,
            events: events.sorted { $0.time < $1.time }
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
        initialCoins.removeAll(keepingCapacity: true)
        events.removeAll(keepingCapacity: true)
        lastSampleTime = nil
        lastObservedPose = nil
    }

    private func recordEvent(
        kind: ConsumentaGhostEvent.Kind,
        objectID: UUID,
        objectType: MapObjectType?,
        x: Float,
        z: Float
    ) {
        guard ConsumentaConfiguration.isEnabled,
              raceDuration == nil,
              let startedAt else {
            return
        }

        events.append(
            ConsumentaGhostEvent(
                id: UUID(),
                time: Date().timeIntervalSince(startedAt),
                kind: kind,
                objectID: objectID,
                objectType: objectType,
                x: x,
                z: z
            )
        )
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

        if force == false,
           let lastSample = samples.last {
            let elapsed = max(0, Float(time - lastSample.time))
            let distance = hypot(
                pose.position.x - lastSample.x,
                pose.position.z - lastSample.z
            )
            let maximumDistance = positionTolerance
                + maximumPlausibleSpeed * elapsed

            guard distance <= maximumDistance else {
                return
            }
        }

        let stabilizedRotation: Float
        if let lastSample = samples.last {
            var bestDelta = atan2(
                sin(pose.rotation - lastSample.rotation),
                cos(pose.rotation - lastSample.rotation)
            )

            // Only consider the planar AprilTag ambiguity for an impossible
            // single-frame jump. Normal turns, including crossing ±π, keep
            // their direction and can accumulate beyond a full revolution.
            if abs(bestDelta) > aprilTagFlipThreshold {
                let flippedDelta = atan2(
                    sin(pose.rotation + .pi - lastSample.rotation),
                    cos(pose.rotation + .pi - lastSample.rotation)
                )
                if abs(flippedDelta) < abs(bestDelta) {
                    bestDelta = flippedDelta
                }
            }
            stabilizedRotation = lastSample.rotation + bestDelta
        } else {
            stabilizedRotation = pose.rotation
        }

        samples.append(
            ConsumentaDriveSample(
                time: time,
                x: pose.position.x,
                z: pose.position.z,
                rotation: stabilizedRotation
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
