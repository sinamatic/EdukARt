import Foundation

/// Temporary local coordinates for the floor-anchored demo scene.
struct ExampleTrack {
    let trackPoints = [
        StoredTrackPoint(x: 0, z: 0),
        StoredTrackPoint(x: 0, z: -2)
    ]

    let objects: [PlacedMapObject] = [
        PlacedMapObject(type: .shit, x: -0.24, z: -0.55),
        PlacedMapObject(type: .oil, x: 0.24, z: -0.85),
        PlacedMapObject(type: .water, x: 0.68, z: -1.45),
        PlacedMapObject(type: .itembox, x: -0.55, z: -1.45),
        PlacedMapObject(type: .tree, x: -0.95, z: -0.9),
        PlacedMapObject(type: .rock, x: 0.96, z: -0.65),
        PlacedMapObject(type: .eggs, x: -0.40, z: -1.75),
        PlacedMapObject(type: .eggCup, x: 0, z: -2.36)
    ]

    let coins: [GameCoin] = [
        GameCoin(id: UUID(), position: SIMD2<Float>(0, -1.25))
    ]
}
