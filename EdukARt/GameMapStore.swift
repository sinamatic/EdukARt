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
        installBundledConsumentaCoursesIfNeeded()
    }


    // MARK: - Consumenta Export

    func exportConsumentaCourses() throws -> URL {

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
                    "ConsumentaCourses.json"
                )

        try data.write(
            to: exportURL,
            options: .atomic
        )

        return exportURL
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


    // MARK: - Consumenta Bundled Courses

    private func installBundledConsumentaCoursesIfNeeded() {

        guard ConsumentaConfiguration.isEnabled,
              UserDefaults.standard.integer(
                forKey: "consumentaBundledCourseVersion"
              ) != ConsumentaConfiguration.bundledCourseVersion,
              let bundledURL = Bundle.main.url(
                forResource: ConsumentaConfiguration.bundledCourseResourceName,
                withExtension: "json"
              ),
              let data = try? Data(contentsOf: bundledURL),
              let bundledMaps = try? JSONDecoder().decode(
                [GameMap].self,
                from: data
              ),
              bundledMaps.isEmpty == false
        else {
            return
        }

        maps = bundledMaps
        saveToDisk()

        UserDefaults.standard.set(
            ConsumentaConfiguration.bundledCourseVersion,
            forKey: "consumentaBundledCourseVersion"
        )
    }
}
