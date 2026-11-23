import RealityKit
import simd

struct ARAnimatedMapObject {
    let entity: Entity
    let type: MapObjectType
    let basePosition: SIMD3<Float>
    let baseOrientation: simd_quatf
    let phase: Float
}

enum ARMapObjectContent {
    static func makeEntity(for object: PlacedMapObject) throws -> Entity? {
        guard let modelName = object.type.modelName else { return nil }
        let model = try Entity.load(named: modelName)
        model.scale *= SIMD3<Float>(repeating: object.type.arModelScale)

        let root = Entity()
        root.name = "ARMapObject-\(object.id)"
        root.position = SIMD3<Float>(object.x, 0, object.z)
        let rotation = object.rotation + (object.type == .eggCup ? .pi : 0)
        root.orientation = simd_quatf(angle: rotation, axis: SIMD3<Float>(0, 1, 0))
        root.addChild(model)
        return root
    }

    static func animation(
        for object: PlacedMapObject,
        entity: Entity,
        phase: Float
    ) -> ARAnimatedMapObject? {
        switch object.type {
        case .oil, .eggCup, .rock, .tree, .treeTrigger:
            return nil
        default:
            break
        }
        return ARAnimatedMapObject(
            entity: entity,
            type: object.type,
            basePosition: entity.position,
            baseOrientation: entity.orientation,
            phase: phase
        )
    }

    static func animate(_ objects: [ARAnimatedMapObject], at elapsedTime: Float) {
        for object in objects {
            let time = elapsedTime + object.phase

            if object.type == .eggs {
                let height = max(0, sin(time * 5)) * 0.03
                object.entity.position = object.basePosition + SIMD3<Float>(0, height, 0)
                object.entity.orientation = object.baseOrientation
            } else if object.type == .water {
                object.entity.position = object.basePosition
                object.entity.orientation = simd_quatf(
                    angle: time * 0.35,
                    axis: SIMD3<Float>(0, 1, 0)
                ) * object.baseOrientation
            } else {
                object.entity.position = object.basePosition
                    + SIMD3<Float>(0, sin(time * 3.2) * 0.018, 0)
                object.entity.orientation = simd_quatf(
                    angle: sin(time * 4) * 0.10,
                    axis: SIMD3<Float>(0, 1, 0)
                ) * object.baseOrientation
            }
        }
    }
}
