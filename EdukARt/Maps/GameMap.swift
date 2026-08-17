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
    var trackElements: [MapTrackElement]
    
    
    init(
        name: String,
        referenceTagID: Int,
        aprilTags: [MapAprilTag],
        trackPoints: [MapPoint] = [],
        trackElements: [MapTrackElement] = []
    ) {
        id = UUID()
        self.name = name
        createdAt = Date()
        self.referenceTagID = referenceTagID
        self.aprilTags = aprilTags
        self.trackPoints = trackPoints
        self.trackElements = trackElements
    }
    
    
}



struct MapAprilTag: Identifiable, Codable {
    
    let id: Int
    
    let x: Float
    let y: Float
    let z: Float
}
