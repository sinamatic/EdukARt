//
//  UITrackElements.swift
//  EdukARt
//
//

import Foundation

enum MapTrackElementType: String, Codable {
    case coin
    case itemBox
    case oil
}

struct MapTrackElement: Identifiable, Codable {
    
    let id: UUID
    let type: MapTrackElementType
    
    let x: Float
    let y: Float
    
    init(
        id: UUID = UUID(),
        type: MapTrackElementType,
        x: Float,
        y: Float
    ) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
    }
}

