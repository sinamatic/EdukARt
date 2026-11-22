import Foundation
import Combine

enum DriveEduardType: String, Codable {
    case physicalEduard
    case arEduard
}

struct DriveSample: Codable {
    let time: TimeInterval
    let x: Float
    let z: Float
    let rotation: Float

    var pose: RobotPose {
        RobotPose(position: SIMD3<Float>(x, 0, z), rotation: rotation)
    }
}

// Item events are independent of pose samples. The current robot-only ghost
// needs no item events, but the format can carry them for a later world replay.
struct DriveItemEvent: Codable {
    let time: TimeInterval
    let objectID: UUID
    let kind: String
}

struct DriveRecording: Codable {
    let formatVersion: Int
    let id: UUID
    let mapID: UUID
    let eduardType: DriveEduardType
    let startedAt: Date
    let samples: [DriveSample]
    let itemEvents: [DriveItemEvent]
}

@MainActor
final class DriveRecorder: ObservableObject {
    private var startedAt: Date?
    private var mapID: UUID?
    private var eduardType: DriveEduardType?
    private var samples: [DriveSample] = []
    private var itemEvents: [DriveItemEvent] = []

    func start(map: GameMap, type: DriveEduardType) {
        mapID = map.id
        eduardType = type
        startedAt = Date()
        samples = []
        itemEvents = []
    }

    func sample(realPose: RobotPose?, simulationPose: RobotPose) {
        guard let startedAt, let eduardType else { return }
        let pose: RobotPose
        switch eduardType {
        case .physicalEduard:
            guard let realPose else { return }
            pose = realPose
        case .arEduard:
            pose = simulationPose
        }
        guard pose.position.x.isFinite, pose.position.z.isFinite,
              pose.rotation.isFinite else { return }

        samples.append(DriveSample(
            time: Date().timeIntervalSince(startedAt),
            x: pose.position.x,
            z: pose.position.z,
            rotation: pose.rotation
        ))
    }

    func finish(realPose: RobotPose?, simulationPose: RobotPose) throws -> DriveRecording {
        // The shared sampling path may add one final pose at the finish.
        sample(realPose: realPose, simulationPose: simulationPose)
        guard let mapID, let eduardType, let startedAt,
              samples.isEmpty == false else { throw RecordingError.empty }

        let recording = DriveRecording(
            formatVersion: 1,
            id: UUID(),
            mapID: mapID,
            eduardType: eduardType,
            startedAt: startedAt,
            samples: samples,
            itemEvents: itemEvents
        )
        self.startedAt = nil
        return recording
    }

    func reset() {
        startedAt = nil
        samples = []
        itemEvents = []
    }

    static func save(_ recording: DriveRecording) throws {
        let directory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        )[0].appendingPathComponent("Drives", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent(
            "\(recording.mapID.uuidString)-\(recording.id.uuidString).json"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(recording).write(to: url, options: .atomic)
    }

    static func load(mapID: UUID) throws -> DriveRecording {
        let directory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        )[0].appendingPathComponent("Drives", isDirectory: true)
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(mapID.uuidString + "-") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let recordings = urls.compactMap { url in
            try? decoder.decode(DriveRecording.self, from: Data(contentsOf: url))
        }
        guard let latest = recordings.filter({ $0.mapID == mapID })
            .max(by: { $0.startedAt < $1.startedAt }) else {
            throw RecordingError.empty
        }
        return latest
    }

    private enum RecordingError: Error {
        case empty
    }
}

@MainActor
final class GhostPlaybackController: ObservableObject {
    @Published private(set) var isPlaying = false
    let simulation = EduardSimulation()
    private var task: Task<Void, Never>?

    func play(_ recording: DriveRecording, onFinished: @escaping () -> Void = {}) {
        stop()
        guard let first = recording.samples.first else { return }
        simulation.setPose(first.pose)
        simulation.setVisible(true)
        isPlaying = true

        task = Task { @MainActor [weak self] in
            guard let self else { return }
            let start = ProcessInfo.processInfo.systemUptime
            for sample in recording.samples {
                let remaining = sample.time - (ProcessInfo.processInfo.systemUptime - start)
                if remaining > 0 {
                    try? await Task.sleep(for: .seconds(remaining))
                }
                guard Task.isCancelled == false else { return }
                simulation.setPose(sample.pose)
            }
            isPlaying = false
            task = nil
            onFinished()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isPlaying = false
        simulation.setVisible(false)
    }
}
