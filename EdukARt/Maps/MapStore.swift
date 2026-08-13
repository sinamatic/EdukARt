//
//  MapStore.swift
//  EdukARt
//

import Foundation
import Combine

final class MapStore: ObservableObject {
    
    @Published private(set) var maps: [GameMap] = []
    
    private let fileManager = FileManager.default
    
    init() {
        load()
    }
    
    
    func save(_ map: GameMap) throws {
        maps.insert(map, at: 0)
        try persist()
    }
    
    
    func delete(_ map: GameMap) throws {
        maps.removeAll { $0.id == map.id }
        try persist()
    }
    
    
    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else {
            return
        }
        
        maps = (try? JSONDecoder().decode([GameMap].self, from: data)) ?? []
    }
    
    
    private func persist() throws {
        let folderURL = storageURL.deletingLastPathComponent()
        
        try fileManager.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        
        let data = try JSONEncoder().encode(maps)
        try data.write(to: storageURL)
    }
    
    
    private var storageURL: URL {
        let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        return documentsURL.appendingPathComponent("game-maps.json")
    }
}
