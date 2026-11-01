import SwiftUI
import SwiftUIJoystick
import UIKit

struct SpectatorPlaybackView: View {
    let maps: [GameMap]
    let ghosts: [SpectatorGhost]
    private let leaderboards: [SpectatorCourseLeaderboard]

    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var controller: RobotController

    @Environment(\.dismiss) private var dismiss

    @StateObject private var gameController: GameController
    @StateObject private var replayController = ConsumentaGhostReplayController()
    @StateObject private var joystickMonitor = JoystickMonitor()
    @StateObject private var turnJoystickMonitor = JoystickMonitor()
    @StateObject private var mapBuilder = AprilTagMapBuilder()

    @State private var phase: SpectatorPlaybackPhase = .localizing
    @State private var activeIndex = 0
    @State private var loopTask: Task<Void, Never>?
    @State private var localizationResetID = 0

    init(
        maps: [GameMap],
        ghosts: [SpectatorGhost],
        eduardModelStore: EduardModelStore,
        controller: RobotController
    ) {
        self.maps = maps
        self.ghosts = ghosts
        self.eduardModelStore = eduardModelStore
        self.controller = controller
        leaderboards = maps.map { map in
            SpectatorCourseLeaderboard(
                id: map.id,
                name: map.name,
                ghosts: ghosts
                    .filter { $0.mapID == map.id }
                    .sorted { first, second in
                        first.ranks(before: second)
                    }
            )
        }
        _gameController = StateObject(
            wrappedValue: GameController(map: maps[0])
        )
    }

    var body: some View {
        ZStack {
            SpectatorARView(
                map: activeMap,
                eduardModelStore: eduardModelStore,
                controller: controller,
                gameController: gameController,
                joystickMonitor: joystickMonitor,
                turnJoystickMonitor: turnJoystickMonitor,
                mapBuilder: mapBuilder,
                localizationResetID: localizationResetID,
                onLocalized: mapLocalized
            )

            switch phase {
            case .localizing, .ready:
                SpectatorLocalizationOverlay(
                    referenceTagID: maps[0].referenceTagID,
                    isReady: phase == .ready,
                    onStart: beginLoop
                )

            case .leaderboard:
                SpectatorLeaderboardOverlay(
                    leaderboards: leaderboards,
                    activeID: activeGhost.id,
                    onExit: exit
                )

            case .playing:
                SpectatorPlayingOverlay(
                    playerName: activeGhost.playerName,
                    mapName: activeGhost.mapName,
                    eduardType: activeGhost.eduardType,
                    duration: activeGhost.duration,
                    rank: activeCourseRank,
                    total: activeCourseGhostCount,
                    startedAt: activeGhost.startedAt,
                    onExit: exit
                )
            }
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            controller.isSpectatorModeActive = true
            controller.sendDisable()
            controller.setGameplayInputLocked(true)
            controller.isLiveSyncEnabled = false
            controller.setSimulationVisible(false)
            controller.ghostSimulation.setVisible(false)
        }
        .onDisappear {
            controller.isSpectatorModeActive = false
            stopPlayback()
        }
    }

    private var activeGhost: SpectatorGhost {
        ghosts[activeIndex]
    }

    private var activeMap: GameMap {
        maps.first { $0.id == activeGhost.mapID } ?? maps[0]
    }

    private var activeCourseRank: Int {
        guard let leaderboard = leaderboards.first(where: {
            $0.id == activeGhost.mapID
        }), let index = leaderboard.ghosts.firstIndex(where: {
            $0.id == activeGhost.id
        }) else {
            return 1
        }

        return index + 1
    }

    private var activeCourseGhostCount: Int {
        leaderboards.first { $0.id == activeGhost.mapID }?.ghosts.count ?? 1
    }

    private func mapLocalized() {
        guard phase == .localizing else {
            return
        }

        withAnimation(.easeInOut(duration: 0.35)) {
            phase = .ready
        }
    }

    private func beginLoop() {
        activeIndex = 0
        showLeaderboard()
    }

    private func showLeaderboard() {
        replayController.reset()
        gameController.endGhostPlayback()
        gameController.reset(map: activeMap)
        controller.ghostSimulation.setVisible(false)

        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .leaderboard
        }

        loopTask?.cancel()
        loopTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(20))

            guard Task.isCancelled == false else {
                return
            }

            playActiveGhost()
        }
    }

    private func playActiveGhost() {
        replayController.prepare(
            recordingURL: activeGhost.fileURL,
            mode: .replay,
            simulation: controller.ghostSimulation
        )

        guard replayController.phase != .failed else {
            advanceToNextGhost()
            return
        }

        replayController.referenceLocalized()
        controller.ghostSimulation.setOpacity(1)
        controller.ghostSimulation.setVisible(true)

        if let recording = replayController.recording {
            gameController.beginGhostPlayback(
                recording: recording,
                mode: .replay
            )
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .playing
        }

        replayController.start(
            simulation: controller.ghostSimulation,
            onPoseUpdated: { pose in
                gameController.updateGhostPlaybackPose(pose)
            },
            onEvent: { event in
                gameController.applyGhostEvent(event)
                applyVisualEffect(event)
            },
            onFinished: {
                gameController.endGhostPlayback()
                controller.ghostSimulation.setVisible(false)
                advanceToNextGhost()
            }
        )
    }

    private func advanceToNextGhost() {
        activeIndex = (activeIndex + 1) % ghosts.count
        showLeaderboard()
    }

    private func applyVisualEffect(_ event: ConsumentaGhostEvent) {
        switch event.kind {
        case .objectExited:
            break
        case .coinCollected:
            controller.ghostSimulation.blinkLights(
                color: .systemYellow,
                duration: 0.8
            )
        case .objectEntered:
            switch event.objectType {
            case .shit:
                controller.ghostSimulation.startShitEffect(duration: 5)
            case .oil:
                controller.ghostSimulation.startOilEffect(duration: 5)
            case .itembox:
                controller.ghostSimulation.blinkLights(color: .systemGreen)
            case .eggs, .eggCup:
                controller.ghostSimulation.blinkLights(color: .systemYellow)
            case .tree, .treeTrigger:
                controller.ghostSimulation.blinkLights(color: .systemOrange)
            case .water, .rock, .none:
                break
            }
        }
    }

    private func exit() {
        stopPlayback()
        dismiss()
    }

    private func stopPlayback() {
        loopTask?.cancel()
        loopTask = nil
        replayController.reset()
        gameController.endGhostPlayback()
        controller.ghostSimulation.setVisible(false)
        controller.ghostSimulation.setPose(.zero)
        controller.setGameplayInputLocked(false)
    }
}

private struct SpectatorCourseLeaderboard: Identifiable {
    let id: UUID
    let name: String
    let ghosts: [SpectatorGhost]
}

private enum SpectatorPlaybackPhase: Equatable {
    case localizing
    case ready
    case leaderboard
    case playing
}

private struct SpectatorARView: View {
    let map: GameMap
    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var controller: RobotController
    @ObservedObject var gameController: GameController
    @ObservedObject var joystickMonitor: JoystickMonitor
    @ObservedObject var turnJoystickMonitor: JoystickMonitor
    @ObservedObject var mapBuilder: AprilTagMapBuilder
    let localizationResetID: Int
    let onLocalized: () -> Void

    var body: some View {
        CameraARView(
            eduardModelStore: eduardModelStore,
            joystickMonitor: joystickMonitor,
            turnJoystickMonitor: turnJoystickMonitor,
            mapBuilder: mapBuilder,
            controller: controller,
            gameController: gameController,
            gameMap: map,
            localizationResetID: localizationResetID,
            requiredReferenceTagID: map.referenceTagID,
            onReferenceTagLocalized: onLocalized,
            onRobotPoseUpdated: { _ in },
            onRobotPoseLost: {
                controller.eduardOccluder.setEnabled(false)
            }
        )
        .ignoresSafeArea()
    }
}

private struct SpectatorLocalizationOverlay: View {
    let referenceTagID: Int
    let isReady: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 12) {
                Label(
                    isReady ? "Map Localized" : "Localize Map",
                    systemImage: isReady
                        ? "checkmark.circle.fill"
                        : "viewfinder"
                )
                .font(.title2.bold())

                if isReady {
                    Text("The courses are ready for spectator playback.")

                    Button("Start", action: onStart)
                        .buttonStyle(.borderedProminent)
                        .tint(Color("BrandGreen"))
                        .controlSize(.large)
                } else {
                    ProgressView()
                        .tint(.white)

                    Text(
                        "Point the iPad camera at reference AprilTag #\(referenceTagID)."
                    )
                }
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: 480)
            .background(.black.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 24))

            Spacer()
        }
        .padding()
    }
}

private struct SpectatorLeaderboardOverlay: View {
    let leaderboards: [SpectatorCourseLeaderboard]
    let activeID: UUID
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SpectatorLeaderboardHeader(onExit: onExit)

            HStack(alignment: .top, spacing: 14) {
                ForEach(leaderboards) { leaderboard in
                    SpectatorCourseLeaderboardTable(
                        name: leaderboard.name,
                        ghosts: leaderboard.ghosts,
                        activeID: activeID
                    )
                }
            }
            .padding(16)
        }
        .background(.black.opacity(0.92))
        .foregroundStyle(.white)
    }
}

private struct SpectatorLeaderboardHeader: View {
    let onExit: () -> Void

    var body: some View {
        HStack {
            Text("Leaderboards")
                .font(.largeTitle.bold())

            Spacer()

            Button("Exit", action: onExit)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.black.opacity(0.75))
    }
}

private struct SpectatorCourseLeaderboardTable: View {
    let name: String
    let ghosts: [SpectatorGhost]
    let activeID: UUID

    var body: some View {
        VStack(spacing: 10) {
            Text(name)
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)

            SpectatorCourseColumnHeader()

            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(Array(ghosts.enumerated()), id: \.element.id) {
                        index,
                        ghost in
                        SpectatorLeaderboardRow(
                            rank: index + 1,
                            playerName: ghost.playerName,
                            eduardType: ghost.eduardType,
                            duration: ghost.duration,
                            isActive: ghost.id == activeID
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct SpectatorCourseColumnHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Rank")
                .frame(width: 44, alignment: .leading)
            Text("Player")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Eduard")
                .frame(width: 82, alignment: .leading)
            Text("Time")
                .frame(width: 72, alignment: .trailing)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
    }
}

private struct SpectatorLeaderboardRow: View {
    let rank: Int
    let playerName: String
    let eduardType: ConsumentaEduardType?
    let duration: TimeInterval
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("#\(rank)")
                .font(.headline)
                .frame(width: 44, alignment: .leading)

            Text(playerName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(eduardType?.displayName ?? "Unknown")
                .font(.caption)
                .lineLimit(1)
                .frame(width: 82, alignment: .leading)

            Text(Self.time(duration))
                .font(.subheadline.monospacedDigit().bold())
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .foregroundStyle(isActive ? .white : .secondary)
        .background(
            isActive
                ? Color("BrandGreen").opacity(0.78)
                : Color.white.opacity(0.06)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.25), value: isActive)
    }

    fileprivate static func time(_ interval: TimeInterval) -> String {
        String(
            format: "%d:%05.2f",
            Int(interval) / 60,
            interval.truncatingRemainder(dividingBy: 60)
        )
    }
}

private struct SpectatorPlayingOverlay: View {
    let playerName: String
    let mapName: String
    let eduardType: ConsumentaEduardType?
    let duration: TimeInterval
    let rank: Int
    let total: Int
    let startedAt: Date
    let onExit: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 14) {
                Text("\(mapName) · #\(rank) of \(total)")
                    .font(.title2.bold())

                Text(playerName)
                    .font(.title2.weight(.semibold))

                Spacer()

                Button("Exit", action: onExit)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(.black.opacity(0.76))

            Spacer()

            HStack(spacing: 22) {
                Label(
                    eduardType?.displayName ?? "Unknown Eduard",
                    systemImage: "car.side"
                )
                Label(
                    SpectatorLeaderboardRow.time(duration),
                    systemImage: "stopwatch"
                )
                Label(
                    startedAt.formatted(date: .numeric, time: .shortened),
                    systemImage: "calendar"
                )
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(.black.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.bottom, 20)
        }
    }
}
