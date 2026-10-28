import Combine
import Foundation

@MainActor
final class ConsumentaGhostReplayController: ObservableObject {
    enum Phase: Equatable {
        case inactive
        case awaitingReference
        case ready
        case playing
        case finished
        case failed
    }

    @Published private(set) var phase: Phase = .inactive

    private var recording: ConsumentaDriveRecording?
    private var replayTask: Task<Void, Never>?

    func prepare(
        recordingURL: URL,
        simulation: EduardSimulation
    ) {
        replayTask?.cancel()

        do {
            let data = try Data(contentsOf: recordingURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let recording = try decoder.decode(
                ConsumentaDriveRecording.self,
                from: data
            )

            guard let firstSample = recording.samples.first else {
                phase = .failed
                return
            }

            self.recording = recording
            simulation.setPose(firstSample.robotPose)
            phase = .awaitingReference
        } catch {
            recording = nil
            phase = .failed
        }
    }

    func referenceLocalized() {
        guard phase == .awaitingReference else {
            return
        }

        phase = .ready
    }

    func start(simulation: EduardSimulation) {
        guard phase == .ready,
              let recording,
              recording.samples.isEmpty == false else {
            return
        }

        replayTask?.cancel()
        phase = .playing

        replayTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            simulation.setPose(recording.samples[0].robotPose)

            for index in 1..<recording.samples.count {
                guard Task.isCancelled == false else {
                    return
                }

                let previous = recording.samples[index - 1]
                let current = recording.samples[index]
                await animate(
                    from: previous,
                    to: current,
                    simulation: simulation
                )
            }

            guard Task.isCancelled == false else {
                return
            }

            phase = .finished
        }
    }

    func reset() {
        replayTask?.cancel()
        replayTask = nil
        recording = nil
        phase = .inactive
    }

    private func animate(
        from start: ConsumentaDriveSample,
        to end: ConsumentaDriveSample,
        simulation: EduardSimulation
    ) async {
        let duration = max(0, end.time - start.time)
        let steps = max(1, Int(ceil(duration * 30)))
        let stepDuration = duration / Double(steps)
        let rotationDelta = atan2(
            sin(end.rotation - start.rotation),
            cos(end.rotation - start.rotation)
        )

        for step in 1...steps {
            guard Task.isCancelled == false else {
                return
            }

            let progress = Float(step) / Float(steps)
            let pose = RobotPose(
                position: SIMD3<Float>(
                    start.x + (end.x - start.x) * progress,
                    0,
                    start.z + (end.z - start.z) * progress
                ),
                rotation: start.rotation + rotationDelta * progress
            )

            simulation.setPose(pose)

            if stepDuration > 0 {
                try? await Task.sleep(
                    for: .seconds(stepDuration)
                )
            }
        }
    }
}

private extension ConsumentaDriveSample {
    var robotPose: RobotPose {
        RobotPose(
            position: SIMD3<Float>(x, 0, z),
            rotation: rotation
        )
    }
}
