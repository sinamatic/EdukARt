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
    
    var mapObjects:
        [PlacedMapObject]

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
        trackPoints: [StoredTrackPoint] = [],
        mapObjects: [PlacedMapObject] = []
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
        
        self.mapObjects =
                mapObjects
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
        case mapObjects
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
        
        mapObjects =
            try container.decodeIfPresent(
                [PlacedMapObject].self,
                forKey:
                    .mapObjects
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

// MARK: - Map Object Type

enum MapObjectType:
    String,
    Codable,
    CaseIterable {

    // Items
    case tongue
    case eggs
    case shit

    // Obstacles
    case oil
    case water
    case rock
    case tree


    var symbol: String {

        switch self {

        case .tongue:
            "👅"

        case .eggs:
            "🥚"

        case .shit:
            "💩"

        case .oil:
            "🛢"

        case .water:
            "💧"

        case .rock:
            "🪨"

        case .tree:
            "🌳"
        }
    }


    var name: String {

        switch self {

        case .tongue:
            "Tongue"

        case .eggs:
            "Eggs"

        case .shit:
            "Shit"

        case .oil:
            "Oil"

        case .water:
            "Water"

        case .rock:
            "Rock"

        case .tree:
            "Tree"
        }
    }


    var isObstacle: Bool {

        switch self {

        case .oil,
             .water,
             .rock,
             .tree:
            true

        default:
            false
        }
    }

    var modelName: String? {

        switch self {

        case .shit:
            "Shit"

        default:
            nil
        }
    }
}


// MARK: - Placed Map Object

struct PlacedMapObject:
    Identifiable,
    Codable {

    let id:
        UUID

    let type:
        MapObjectType

    var x:
        Float

    var z:
        Float

    var rotation:
        Float


    init(
        id: UUID = UUID(),
        type: MapObjectType,
        x: Float,
        z: Float,
        rotation: Float = 0
    ) {

        self.id =
            id

        self.type =
            type

        self.x =
            x

        self.z =
            z

        self.rotation =
            rotation
    }
}
