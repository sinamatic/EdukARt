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
}

struct ConsumentaDriveSample: Codable {
    let time: TimeInterval
    let x: Float
    let z: Float
    let rotation: Float
}
