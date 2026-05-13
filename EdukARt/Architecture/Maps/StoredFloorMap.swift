//
//  StoredFloorMap.swift
//  EdukARt
//
//

import Foundation

enum StoredFloorMapConstants {
    static let tileSize: Float = 0.25
    static let referenceTagName = "tag36h11-3"
}

struct StoredFloorMap: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let createdAt: Date
    let minimumAreaSquareMeters: Float
    let floorTileSize: Float
    let referenceTagName: String?
    let floorTiles: [StoredFloorTile]
}

struct StoredFloorTile: Codable, Equatable {
    let x: Float
    let y: Float
    let z: Float
}
