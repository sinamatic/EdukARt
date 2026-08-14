//
//  MapPoint.swift
//  EdukARt
//

import Foundation

struct MapPoint: Codable, Identifiable {
    
    let id: UUID
    let x: Float
    let y: Float
    
    init(
        id: UUID = UUID(),
        x: Float,
        y: Float
    ) {
        self.id = id
        self.x = x
        self.y = y
    }
}
