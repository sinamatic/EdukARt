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
    
    var trackPoints: [MapPoint]
    
    
    init(
        name: String,
        referenceTagID: Int,
        aprilTags: [MapAprilTag],
        trackPoints: [MapPoint] = []
    ) {
        id = UUID()
        self.name = name
        createdAt = Date()
        self.referenceTagID = referenceTagID
        self.aprilTags = aprilTags
        self.trackPoints = trackPoints
    }
}



struct MapAprilTag: Identifiable, Codable {
    
    let id: Int
    
    let x: Float
    let y: Float
    let z: Float
}
