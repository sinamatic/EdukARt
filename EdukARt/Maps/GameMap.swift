//
//  GameMap.swift
//  EdukARt
//

import Foundation

struct GameMap: Identifiable, Codable {
    
    let id: UUID
    var name: String
    let createdAt: Date
    
    init(name: String) {
        id = UUID()
        self.name = name
        createdAt = Date()
    }
}
// ToDo April Tags
// RoomOutline
// Obstackles, Track, TrackWidth, PlacedItems


