//
//  MapStore.swift
//  EdukARt
//
//

import Combine
import Foundation

final class MapStore: ObservableObject {
    @Published private(set) var maps: [StoredFloorMap] = []

    private let fileManager = FileManager.default

    init() {
        load()
    }

    func save(_ map: StoredFloorMap) throws {
        maps.insert(map, at: 0)
        try persist()
    }

    func delete(_ map: StoredFloorMap) throws {
        maps.removeAll { $0.id == map.id }
        try persist()
    }

    func estimatedStorageSize(for map: StoredFloorMap) -> Int {
        (try? JSONEncoder.prettyPrinted.encode(map).count) ?? 0
    }

    func load() {
        do {
            let data = try Data(contentsOf: storageURL)
            maps = try JSONDecoder.iso8601Decoder.decode([StoredFloorMap].self, from: data)
        } catch {
            maps = []
        }
    }

    private func persist() throws {
        let directoryURL = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.prettyPrinted.encode(maps)
        try data.write(to: storageURL, options: [.atomic])
    }

    private var storageURL: URL {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return appSupportURL
            .appendingPathComponent("EdukARt", isDirectory: true)
            .appendingPathComponent("stored-floor-maps.json")
    }
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var iso8601Decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
