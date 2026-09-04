//
//  CollisionManager.swift
//  EdukARt-Rebuild
//
//  Performs simple two-dimensional collision detection
//  between Eduard and placed map objects.
//
//  Both the robot and map objects are approximated
//  as circles in map coordinates.
//

import Foundation
import simd


final class CollisionManager {

    // Eduard is approximately 38 x 41 cm.
    let robotRadius:
        Float = 0.205


    // Objects currently touched by the robot.
    //
    // This prevents one collision from being triggered
    // continuously every frame.
    private var activeCollisionIDs:
        [CollisionActor: Set<UUID>] = [:]


    // MARK: - Update

    func update(
        actor: CollisionActor,
        robotPose: RobotPose,
        objects: [PlacedMapObject]
    ) -> [MapObjectCollision] {

        let robotX =
            robotPose.position.x

        let robotZ =
            robotPose.position.z


        var currentCollisionIDs:
            Set<UUID> = []

        let actorCollisionIDs =
            activeCollisionIDs[actor]
            ?? []

        var collisions:
            [MapObjectCollision] = []


        for object in objects {

            guard let triggerRadius =
                object.type.triggerRadius
            else {
                continue
            }


            let dx =
                robotX - object.x

            let dz =
                robotZ - object.z


            let distanceSquared =
                dx * dx
                +
                dz * dz

            if object.type == .shit {

                let distance =
                    sqrt(
                        distanceSquared
                    )

                print(
                    "# COLLISION DEBUG | Actor:",
                    actor.rawValue,
                    "| Robot:",
                    robotX,
                    robotZ,
                    "| Shit:",
                    object.x,
                    object.z,
                    "| Distance:",
                    distance
                )
            }


            let collisionDistance =
                robotRadius
                +
                triggerRadius


            let collisionDistanceSquared =
                collisionDistance
                *
                collisionDistance


            guard distanceSquared
                    <= collisionDistanceSquared

            else {
                continue
            }


            currentCollisionIDs.insert(
                object.id
            )


            // New collision.

            if actorCollisionIDs
                .contains(
                    object.id
                ) == false {

                collisions.append(
                    MapObjectCollision(
                        object:
                            object,

                        actor:
                            actor,

                        phase:
                            .began
                    )
                )
            }
        }


        // Detect objects that are no longer touched.

        let endedCollisionIDs =
            actorCollisionIDs
                .subtracting(
                    currentCollisionIDs
                )


        for id in endedCollisionIDs {

            guard let object =
                objects.first(
                    where: {
                        $0.id == id
                    }
                )

            else {
                continue
            }


            collisions.append(
                MapObjectCollision(
                    object:
                        object,

                    actor:
                        actor,

                    phase:
                        .ended
                )
            )
        }


        activeCollisionIDs[actor] =
            currentCollisionIDs


        return collisions
    }


    // MARK: - Blocking Check

    func isMovementBlocked(
        robotPose:
            RobotPose,

        command:
            RobotDriveCommand,

        objects:
            [PlacedMapObject],

        revealedTreeIDs:
            Set<UUID>,

        predictionTime:
            Float = 0.10,

        additionalSafetyMargin:
            Float = 0
    ) -> Bool {

        let currentPosition =
            SIMD2<Float>(
                robotPose.position.x,
                robotPose.position.z
            )

        let predictedPosition =
            predictedPosition(
                from:
                    robotPose,

                command:
                    command,

                predictionTime:
                    predictionTime
            )


        for object in objects {

            guard let blockingRadius =
                object.type.blockingRadius
            else {
                continue
            }

            if object.type == .tree,
               revealedTreeIDs.contains(
                object.id
               ) == false {

                continue
            }


            let obstaclePosition =
                blockingPosition(
                    for:
                        object
                )

            let minimumDistance =
                robotRadius
                +
                blockingRadius
                +
                additionalSafetyMargin

            let currentDistance =
                simd_distance(
                    currentPosition,
                    obstaclePosition
                )

            let predictedDistance =
                simd_distance(
                    predictedPosition,
                    obstaclePosition
                )


            if predictedDistance < minimumDistance,
               predictedDistance < currentDistance {

                return true
            }
        }


        return false
    }


    private func predictedPosition(
        from pose:
            RobotPose,

        command:
            RobotDriveCommand,

        predictionTime:
            Float
    ) -> SIMD2<Float> {

        let yaw =
            pose.rotation

        let forward =
            Float(
                command.forward
            )

        let sideways =
            -Float(
                command.sideways
            )

        let sinRotation =
            sin(
                yaw
            )

        let cosRotation =
            cos(
                yaw
            )

        let worldX =
            sideways
            * cosRotation
            +
            forward
            * -sinRotation

        let worldZ =
            forward
            * -cosRotation
            -
            sideways
            * sinRotation

        return SIMD2<Float>(
            pose.position.x
            +
            worldX
            * predictionTime,

            pose.position.z
            +
            worldZ
            * predictionTime
        )
    }


    private func blockingPosition(
        for object:
            PlacedMapObject
    ) -> SIMD2<Float> {

        SIMD2<Float>(
            object.x,
            object.z
        )
    }


    // MARK: - Reset

    func reset() {

        activeCollisionIDs
            .removeAll()
    }
}


// MARK: - Collision Actor

enum CollisionActor:
    String {

    case real
    case simulation
}


// MARK: - Collision

struct MapObjectCollision {

    let object:
        PlacedMapObject

    let actor:
        CollisionActor

    let phase:
        CollisionPhase
}


enum CollisionPhase {

    case began

    case ended
}
