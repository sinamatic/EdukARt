import Foundation

struct ConsumentaDriveRecording: Codable, Identifiable {
    let formatVersion: Int
    let id: UUID
    let mapID: UUID
    let mapName: String
    let playerName: String
    let startedAt: Date
    let duration: TimeInterval
    let samples: [ConsumentaDriveSample]
    let initialCoins: [ConsumentaRecordedCoin]
    let events: [ConsumentaGhostEvent]
}

struct ConsumentaDriveSample: Codable {
    let time: TimeInterval
    let x: Float
    let z: Float
    let rotation: Float
}

struct ConsumentaRecordedCoin: Codable, Identifiable {
    let id: UUID
    let x: Float
    let z: Float
}

struct ConsumentaGhostEvent: Codable, Identifiable {
    enum Kind: String, Codable {
        case coinCollected
        case objectEntered
        case objectExited
    }

    let id: UUID
    let time: TimeInterval
    let kind: Kind
    let objectID: UUID
    let objectType: MapObjectType?
    let x: Float
    let z: Float
}

enum GhostPlaybackMode: String, Codable {
    case replay
    case liveRaceGhost
}
