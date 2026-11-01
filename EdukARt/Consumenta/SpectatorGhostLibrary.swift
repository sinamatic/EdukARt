import Foundation
import Combine

struct SpectatorGhost: Identifiable {
    let recording: ConsumentaDriveRecording
    let fileURL: URL

    var id: UUID { recording.id }
    var playerName: String { recording.playerName }
    var eduardType: ConsumentaEduardType? { recording.eduardType }
    var mapID: UUID { recording.mapID }
    var mapName: String { recording.mapName }
    var startedAt: Date { recording.startedAt }
    var duration: TimeInterval { recording.duration }

    func ranks(before other: SpectatorGhost) -> Bool {
        if rankingGroup != other.rankingGroup {
            return rankingGroup < other.rankingGroup
        }

        if duration != other.duration {
            return duration < other.duration
        }

        return startedAt < other.startedAt
    }

    private var rankingGroup: Int {
        switch eduardType {
        case .physicalEduard:
            0
        case .arEduard:
            1
        case nil:
            2
        }
    }
}

@MainActor
final class SpectatorGhostLibrary: ObservableObject {
    @Published private(set) var ghosts: [SpectatorGhost] = []
    @Published private(set) var errorMessage: String?

    private let directoryURL: URL

    init() {
        directoryURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent(
            "SpectatorGhosts",
            isDirectory: true
        )

        load()
    }

    func importGhosts(from urls: [URL]) {
        errorMessage = nil
        var messages: [String] = []

        for sourceURL in urls {
            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: sourceURL)
                let recording = try Self.decodeRecording(from: data)

                try FileManager.default.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true
                )

                let destinationURL = directoryURL
                    .appendingPathComponent(recording.id.uuidString)
                    .appendingPathExtension("json")

                try data.write(to: destinationURL, options: .atomic)
            } catch {
                messages.append("\(sourceURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        load()

        if messages.isEmpty == false {
            errorMessage = messages.joined(separator: "\n")
        }
    }

    func delete(ids: Set<UUID>) {
        errorMessage = nil

        for ghost in ghosts where ids.contains(ghost.id) {
            do {
                try FileManager.default.removeItem(at: ghost.fileURL)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        load()
    }

    func clearError() {
        errorMessage = nil
    }

    private func load() {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let urls = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            )

            ghosts = urls
                .filter { $0.pathExtension.lowercased() == "json" }
                .compactMap { url in
                    guard let data = try? Data(contentsOf: url),
                          let recording = try? Self.decodeRecording(from: data) else {
                        return nil
                    }

                    return SpectatorGhost(
                        recording: recording,
                        fileURL: url
                    )
                }
                .sorted { first, second in
                    first.startedAt < second.startedAt
                }
        } catch {
            ghosts = []
            errorMessage = error.localizedDescription
        }
    }

    private static func decodeRecording(
        from data: Data
    ) throws -> ConsumentaDriveRecording {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            ConsumentaDriveRecording.self,
            from: data
        )
    }
}
