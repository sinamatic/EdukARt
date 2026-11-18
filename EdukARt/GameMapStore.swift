//
//  GameMapStore.swift
//  EdukARt-Rebuild
//
//  Stores and loads the game maps created by the user.
//

import Foundation
import Combine

// MARK: - Game Map Store

@MainActor
final class GameMapStore:
    ObservableObject {

    @Published private(set)
    var maps:
        [GameMap] = []


    private let fileURL:
        URL


    // MARK: - Init

    init() {

        let documentsDirectory =
            FileManager.default.urls(
                for:
                    .documentDirectory,
                in:
                    .userDomainMask
            )[0]


        fileURL =
            documentsDirectory
                .appendingPathComponent(
                    "game-maps.json"
                )


        load()
        removeBundledConsumentaCoursesIfNeeded()
    }


    // MARK: - Course Export and Import

    func exportAllCourses() throws -> URL {

        let encoder =
            JSONEncoder()

        encoder.outputFormatting =
            [
                .prettyPrinted,
                .sortedKeys
            ]

        let data =
            try encoder.encode(
                maps
            )

        let exportURL =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "EdukARtCourses.json"
                )

        try data.write(
            to: exportURL,
            options: .atomic
        )

        return exportURL
    }


    /// Imports new courses without replacing existing courses or their scores.
    /// Decode and persist the complete result before publishing any changes.
    func importCourses(from url: URL) throws -> (imported: Int, skipped: Int) {
        let data = try Data(contentsOf: url)
        let incoming = try JSONDecoder().decode([GameMap].self, from: data)
        var knownIDs = Set(maps.map(\.id))
        let additions = incoming.filter { knownIDs.insert($0.id).inserted }

        guard !additions.isEmpty else {
            return (0, incoming.count)
        }

        let updatedMaps = maps + additions
        let encoded = try JSONEncoder().encode(updatedMaps)
        try encoded.write(to: fileURL, options: .atomic)
        maps = updatedMaps
        return (additions.count, incoming.count - additions.count)
    }


    // MARK: - Save Map

    func save(
        _ map: GameMap
    ) {

        if let index =
            maps.firstIndex(
                where: {
                    $0.id == map.id
                }
            ) {

            maps[index] =
                map

        } else {

            maps.append(
                map
            )
        }


        saveToDisk()
    }


    // MARK: - Delete Map

    func delete(
        _ map: GameMap
    ) {

        maps.removeAll {
            $0.id == map.id
        }


        saveToDisk()
    }


    // MARK: - Load

    private func load() {

        guard
            let data =
                try? Data(
                    contentsOf:
                        fileURL
                ),

            let savedMaps =
                try? JSONDecoder()
                    .decode(
                        [GameMap].self,
                        from:
                            data
                    )

        else {
            return
        }


        maps =
            savedMaps
    }


    // MARK: - Save to Disk

    private func saveToDisk() {

        guard let data =
            try? JSONEncoder()
                .encode(
                    maps
                )

        else {
            return
        }


        try? data.write(
            to:
                fileURL,

            options:
                .atomic
        )
    }


    // MARK: - Post-Consumenta Migration

    private func removeBundledConsumentaCoursesIfNeeded() {
        let migrationKey = "consumentaCoursesRemovedForVersion12"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        // Match only the bundled course IDs, never user-chosen course names.
        let bundledIDs: Set<UUID> = Set([
            "38A628E6-26E2-430D-A8DC-586898B0F249",
            "3C734ADA-2445-495B-A13B-9E14A1B9C80E",
            "F54CEEF4-92AB-4306-84EC-04AB43B8875C"
        ].compactMap { UUID(uuidString: $0) })
        let remainingMaps = maps.filter { !bundledIDs.contains($0.id) }

        if remainingMaps.count != maps.count {
            do {
                let data = try JSONEncoder().encode(remainingMaps)
                try data.write(to: fileURL, options: .atomic)
                maps = remainingMaps
            } catch {
                // Retry next launch if persistence fails.
                return
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        UserDefaults.standard.removeObject(forKey: "consumentaBundledCourseVersion")
    }
}
