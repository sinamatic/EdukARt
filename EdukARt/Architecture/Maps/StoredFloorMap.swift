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
    let referenceTagNumber: Int?
    let floorTiles: [StoredFloorTile]
}

extension StoredFloorMap {
    var displayReferenceTagNumber: String {
        if let referenceTagNumber {
            return "#\(referenceTagNumber)"
        }

        guard let referenceTagName else {
            return "Ohne Tag"
        }

        let trailingDigits = referenceTagName
            .reversed()
            .prefix(while: { $0.isNumber })
            .reversed()

        return trailingDigits.isEmpty ? referenceTagName : "#\(String(trailingDigits))"
    }
}

struct StoredFloorTile: Codable, Equatable {
    let x: Float
    let y: Float
    let z: Float
}
