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


final class CollisionManager {

    // Eduard is approximately 38 x 41 cm.
    private let robotRadius:
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

            guard object.type.hasCollision
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
                object.type.collisionRadius


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
