//
//  GameMap.swift
//  EdukARt
//

import Foundation

struct GameMap: Identifiable, Codable {
    
    let id: UUID
    var name: String
    let createdAt: Date
    
    let referenceTagID: Int
    var aprilTags: [MapAprilTag]
    
    
    init(
        name: String,
        referenceTagID: Int,
        aprilTags: [MapAprilTag]
    ) {
        id = UUID()
        self.name = name
        createdAt = Date()
        self.referenceTagID = referenceTagID
        self.aprilTags = aprilTags
    }
}


struct MapAprilTag: Identifiable, Codable {
    
    let id: Int
    
    let x: Float
    let y: Float
    let z: Float
}

// ToDo April Tags
// RoomOutline
// Obstackles, Track, TrackWidth, PlacedItems


