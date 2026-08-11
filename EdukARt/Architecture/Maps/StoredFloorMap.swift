//
//  StoredFloorMap.swift
//  EdukARt
//
//

import Foundation

enum StoredFloorMapConstants {
    static let tileSize: Float = 0.12
    static let supportedReferenceTagNames = Set((0...3).map { "tag36h11-\($0)" })
    static let referenceTagName = "tag36h11-0"
    static let referenceTagPhysicalSizeMeters: Float = 0.13
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
    var activeReferenceTagName: String? {
        referenceTagName == nil ? nil : StoredFloorMapConstants.referenceTagName
    }

    var displayReferenceTagNumber: String {
        guard let activeReferenceTagName else {
            return "No tag"
        }

        let trailingDigits = activeReferenceTagName
            .reversed()
            .prefix(while: { $0.isNumber })
            .reversed()

        return trailingDigits.isEmpty ? activeReferenceTagName : "#\(String(trailingDigits))"
    }
}

struct StoredFloorTile: Codable, Equatable {
    let x: Float
    let y: Float
    let z: Float
}
