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

    private(set) var recording: ConsumentaDriveRecording?
    private(set) var mode: GhostPlaybackMode = .replay
    private var replayTask: Task<Void, Never>?

    func prepare(
        recordingURL: URL,
        mode: GhostPlaybackMode = .replay,
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
            self.mode = mode
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

    func start(
        simulation: EduardSimulation,
        onPoseUpdated: @escaping (RobotPose) -> Void = { _ in },
        onEvent: @escaping (ConsumentaGhostEvent) -> Void,
        onFinished: @escaping () -> Void
    ) {
        guard phase == .ready,
              let recording,
              recording.samples.isEmpty == false else {
            return
        }

        replayTask?.cancel()
        phase = .playing
        let playbackMode = mode

        replayTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            simulation.setPose(recording.samples[0].robotPose)
            onPoseUpdated(recording.samples[0].robotPose)
            var eventIndex = 0

            func emitEvents(upTo time: TimeInterval) {
                guard playbackMode == .replay else {
                    return
                }

                while eventIndex < recording.events.count,
                      recording.events[eventIndex].time <= time {
                    onEvent(recording.events[eventIndex])
                    eventIndex += 1
                }
            }

            emitEvents(upTo: recording.samples[0].time)

            for index in 1..<recording.samples.count {
                guard Task.isCancelled == false else {
                    return
                }

                let previous = recording.samples[index - 1]
                let current = recording.samples[index]
                await animate(
                    from: previous,
                    to: current,
                    simulation: simulation,
                    onPoseUpdated: onPoseUpdated,
                    onTimeUpdated: emitEvents
                )
            }

            guard Task.isCancelled == false else {
                return
            }

            emitEvents(upTo: recording.duration)
            phase = .finished
            onFinished()
        }
    }

    func reset() {
        replayTask?.cancel()
        replayTask = nil
        recording = nil
        mode = .replay
        phase = .inactive
    }

    private func animate(
        from start: ConsumentaDriveSample,
        to end: ConsumentaDriveSample,
        simulation: EduardSimulation,
        onPoseUpdated: (RobotPose) -> Void,
        onTimeUpdated: (TimeInterval) -> Void
    ) async {
        let duration = max(0, end.time - start.time)
        let steps = max(1, Int(ceil(duration * 30)))
        let stepDuration = duration / Double(steps)
        let startRotation = simulation.pose.rotation
        var rotationDelta = atan2(
            sin(end.rotation - startRotation),
            cos(end.rotation - startRotation)
        )
        if abs(rotationDelta) > 1.2 {
            let flippedDelta = atan2(
                sin(end.rotation + .pi - startRotation),
                cos(end.rotation + .pi - startRotation)
            )
            if abs(flippedDelta) < abs(rotationDelta) {
                rotationDelta = flippedDelta
            }
        }

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
                rotation: startRotation + rotationDelta * progress
            )

            simulation.setPose(pose, animateMovement: true)
            onPoseUpdated(pose)
            onTimeUpdated(
                start.time + (end.time - start.time) * Double(progress)
            )

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
