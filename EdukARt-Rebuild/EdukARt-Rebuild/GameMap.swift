//
//  GameMap.swift
//  EdukARt-Rebuild
//
//  Represents a saved game environment.
//  AprilTag positions are stored relative to the
//  reference tag and are independent of the current
//  ARKit session.
//

import Foundation


// MARK: - Game Map

struct GameMap:
    Identifiable,
    Codable {

    let id:
        UUID

    var name:
        String

    let createdAt:
        Date

    let referenceTagID:
        Int

    var aprilTags:
        [StoredAprilTag]


    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        referenceTagID: Int,
        aprilTags: [StoredAprilTag]
    ) {

        self.id =
            id

        self.name =
            name

        self.createdAt =
            createdAt

        self.referenceTagID =
            referenceTagID

        self.aprilTags =
            aprilTags
    }
}


// MARK: - Stored AprilTag

struct StoredAprilTag:
    Identifiable,
    Codable {

    let id:
        Int

    let x:
        Float

    let z:
        Float
    
    
    let rotation:
        Float
}
