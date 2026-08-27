//
//  GameMap.swift
//  EdukARt-Rebuild
//
//  Represents a persistent game environment.
//
//  AprilTag positions define the physical map coordinate
//  system. Track points are stored in the same coordinate
//  system and are independent of the current ARKit session.
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

    // Final normalized track centerline.
    //
    // These are NOT the raw finger input points.
    var trackPoints:
        [StoredTrackPoint]


    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        referenceTagID: Int,
        aprilTags: [StoredAprilTag],
        trackPoints: [StoredTrackPoint] = []
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

        self.trackPoints =
            trackPoints
    }


    // MARK: - Codable

    private enum CodingKeys:
        String,
        CodingKey {

        case id
        case name
        case createdAt
        case referenceTagID
        case aprilTags
        case trackPoints
    }


    init(
        from decoder: Decoder
    ) throws {

        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )


        id =
            try container.decode(
                UUID.self,
                forKey:
                    .id
            )

        name =
            try container.decode(
                String.self,
                forKey:
                    .name
            )

        createdAt =
            try container.decode(
                Date.self,
                forKey:
                    .createdAt
            )

        referenceTagID =
            try container.decode(
                Int.self,
                forKey:
                    .referenceTagID
            )

        aprilTags =
            try container.decode(
                [StoredAprilTag].self,
                forKey:
                    .aprilTags
            )


        // Existing maps created before track support
        // simply receive an empty track.
        trackPoints =
            try container.decodeIfPresent(
                [StoredTrackPoint].self,
                forKey:
                    .trackPoints
            )
            ?? []
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


// MARK: - Stored Track Point

struct StoredTrackPoint:
    Codable {

    let x:
        Float

    let z:
        Float
}
