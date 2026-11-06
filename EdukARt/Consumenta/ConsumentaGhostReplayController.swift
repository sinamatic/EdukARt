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
    private var playbackSamples: [ConsumentaDriveSample] = []
    private var replayTask: Task<Void, Never>?

    func prepare(
        recordingURL: URL,
        mode: GhostPlaybackMode = .replay,
        simulation: EduardSimulation
    ) {
        reset()

        do {
            let data = try Data(contentsOf: recordingURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let recording = try decoder.decode(
                ConsumentaDriveRecording.self,
                from: data
            )

            let samples = Self.removingIsolatedOutliers(recording.samples)
            guard recording.duration.isFinite, recording.duration >= 0,
                  let firstSample = samples.first else {
                phase = .failed
                return
            }

            self.playbackSamples = samples
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
              playbackSamples.isEmpty == false else {
            return
        }

        replayTask?.cancel()
        phase = .playing
        let playbackMode = mode
        let samples = playbackSamples

        replayTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            simulation.setPose(samples[0].robotPose)
            onPoseUpdated(samples[0].robotPose)
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

            // Always evaluate against elapsed time, so rendering delays cannot
            // accumulate into a progressively slower replay.
            let startedAt = ProcessInfo.processInfo.systemUptime
            let endTime = max(recording.duration, samples.last?.time ?? 0)
            var index = 0
            while Task.isCancelled == false {
                let time = min(ProcessInfo.processInfo.systemUptime - startedAt, endTime)
                while index + 1 < samples.count, samples[index + 1].time <= time {
                    index += 1
                }

                let pose: RobotPose
                if time < samples[0].time || index + 1 == samples.count {
                    pose = samples[index].robotPose
                } else {
                    pose = Self.interpolate(
                        from: samples[index],
                        to: samples[index + 1],
                        at: time
                    ).robotPose
                }
                simulation.setPose(pose, animateMovement: true)
                onPoseUpdated(pose)
                emitEvents(upTo: time)

                if time >= endTime {
                    break
                }
                do {
                    try await Task.sleep(for: .seconds(1.0 / 60.0))
                } catch {
                    return
                }
            }

            guard Task.isCancelled == false else {
                return
            }
            phase = .finished
            onFinished()
        }
    }

    func reset() {
        replayTask?.cancel()
        replayTask = nil
        recording = nil
        playbackSamples = []
        mode = .replay
        phase = .inactive
    }

    private static func angleDelta(from start: Float, to end: Float) -> Float {
        atan2(sin(end - start), cos(end - start))
    }

    static func interpolate(
        from start: ConsumentaDriveSample,
        to end: ConsumentaDriveSample,
        at time: TimeInterval
    ) -> ConsumentaDriveSample {
        let progress = Float(max(0, min(1, (time - start.time) / (end.time - start.time))))
        return ConsumentaDriveSample(
            time: time,
            x: start.x + (end.x - start.x) * progress,
            z: start.z + (end.z - start.z) * progress,
            rotation: start.rotation
                + angleDelta(from: start.rotation, to: end.rotation) * progress
        )
    }

    static func removingIsolatedOutliers(
        _ samples: [ConsumentaDriveSample]
    ) -> [ConsumentaDriveSample] {
        var valid: [ConsumentaDriveSample] = []
        for sample in samples {
            guard sample.time.isFinite, sample.time >= 0,
                  sample.x.isFinite, sample.z.isFinite, sample.rotation.isFinite,
                  sample.time > (valid.last?.time ?? -.infinity) else {
                continue
            }
            valid.append(sample)
        }
        guard valid.count >= 3 else {
            return valid
        }

        var result = valid
        // Only repair a brief excursion that returns to consistent neighbours.
        // Never infer heading from motion: reversing, strafing and sustained
        // turns must retain their recorded orientation. Do not bridge long gaps
        // or cascade corrections through already modified samples.
        for index in 1..<(valid.count - 1) {
            let before = valid[index - 1]
            let sample = valid[index]
            let after = valid[index + 1]
            let duration = after.time - before.time
            guard duration <= 1 else {
                continue
            }
            let expected = interpolate(from: before, to: after, at: sample.time)
            let angularSpike =
                abs(angleDelta(from: before.rotation, to: after.rotation)) < 0.35
                && abs(angleDelta(from: before.rotation, to: sample.rotation)) > 0.75
                && abs(angleDelta(from: after.rotation, to: sample.rotation)) > 0.75
            let positionSpike =
                hypot(sample.x - before.x, sample.z - before.z)
                    > 0.1 + 1.5 * Float(sample.time - before.time)
                && hypot(after.x - sample.x, after.z - sample.z)
                    > 0.1 + 1.5 * Float(after.time - sample.time)
                && hypot(after.x - before.x, after.z - before.z) <= 0.1 + 0.75 * Float(duration)
            result[index] = ConsumentaDriveSample(
                time: sample.time,
                x: positionSpike ? expected.x : sample.x,
                z: positionSpike ? expected.z : sample.z,
                rotation: angularSpike ? expected.rotation : sample.rotation
            )
        }
        return result
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
