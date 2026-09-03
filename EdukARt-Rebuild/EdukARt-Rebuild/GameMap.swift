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
    case eggCup
    case eggs
    case shit

    // Obstacles
    case oil
    case water
    case rock
    case tree


    init(
        from decoder:
            Decoder
    ) throws {

        let container =
            try decoder.singleValueContainer()

        let rawValue =
            try container.decode(
                String.self
            )

        switch rawValue {

        case "eggCup":
            self =
                .eggCup

        default:
            guard let type =
                Self(
                    rawValue:
                        rawValue
                )
            else {
                throw DecodingError.dataCorruptedError(
                    in:
                        container,
                    debugDescription:
                        "Invalid map object type: \(rawValue)"
                )
            }

            self =
                type
        }
    }


    func encode(
        to encoder:
            Encoder
    ) throws {

        var container =
            encoder.singleValueContainer()

        try container.encode(
            rawValue
        )
    }


    var symbol: String {

        switch self {

        case .eggCup:
            "🪺"

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

        case .eggCup:
            "Egg Cup"

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
    
    
    // MARK: - Classification

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
    
    // MARK: - Collision
    
    var hasCollision: Bool {

        switch self {

        case .eggCup,
             .eggs,
             .shit,
             .oil,
             .water,
             .rock,
             .tree:

            return true
        } }
        
    var collisionRadius: Float {

        switch self {

        case .eggCup:
            return 0.1 // ToDo: size

        case .eggs:
            return 0.1 // ToDo: size

        case .shit:
            return 0.12 // ToDo: size

        case .oil:
            return 0.25 // ToDo: size

        case .water:
            return 0.15 // ToDo: size

        case .rock:
            return 0.18 // ToDo: size

        case .tree:
            return 0.20 // ToDo: size
        }
   
    
    }


    var arModelScale: Float {

        switch self {

        case .eggCup:
            return 0.2 // ToDo: size

        case .eggs:
            return 0.2 // ToDo: size

        case .oil:
            return 0.15 // ToDo: size

        default:
            return 0.3 // ToDo: size
        }
    }
    
    // MARK: - AR Model

    var modelName: String? {

        switch self {

        case .shit:
            "Shit"

        case .oil:
            "Oil"

        case .eggs:
            "Egg"

        case .eggCup:
            "mrz" // ToDo: size

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
        Float // ToDo: position

    var z:
        Float // ToDo: position

    var rotation:
        Float // ToDo: rotation


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
