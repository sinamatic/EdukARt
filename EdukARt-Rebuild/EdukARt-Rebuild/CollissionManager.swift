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

        blockingLines:
            [BlockingLine] = [],

        revealedTreeIDs:
            Set<UUID>,

        predictionTime:
            Float = 0.10,

        additionalSafetyMargin:
            Float = 0
    ) -> Bool {

        blockingObject(
            robotPose:
                robotPose,

            command:
                command,

            objects:
                objects,

            revealedTreeIDs:
                revealedTreeIDs,

            predictionTime:
                predictionTime,

            additionalSafetyMargin:
                additionalSafetyMargin
        ) != nil
        ||
        isMovementBlockedByBlockingLines(
            robotPose:
                robotPose,

            command:
                command,

            blockingLines:
                blockingLines,

            predictionTime:
                predictionTime,

            additionalSafetyMargin:
                additionalSafetyMargin
        )
    }


    func distanceToTrack(
        robotPose:
            RobotPose,

        trackPoints:
            [StoredTrackPoint]
    ) -> Float {

        guard trackPoints.count >= 2
        else {
            return 0
        }


        let robotPosition =
            SIMD2<Float>(
                robotPose.position.x,
                robotPose.position.z
            )

        var minimumDistance =
            Float.greatestFiniteMagnitude


        for index in
            0..<(trackPoints.count - 1) {

            let start =
                SIMD2<Float>(
                    trackPoints[index].x,
                    trackPoints[index].z
                )

            let end =
                SIMD2<Float>(
                    trackPoints[index + 1].x,
                    trackPoints[index + 1].z
                )

            let segmentDistance =
                distance(
                    from:
                        robotPosition,

                    toSegmentFrom:
                        start,

                    to:
                        end
                )

            minimumDistance =
                min(
                    minimumDistance,
                    segmentDistance
                )
        }


        return minimumDistance
    }


    func isRobotOnRoad(
        robotPose:
            RobotPose,

        trackPoints:
            [StoredTrackPoint]
    ) -> Bool {

        distanceToTrack(
            robotPose:
                robotPose,

            trackPoints:
                trackPoints
        )
        <= TrackRules.roadHalfWidth
    }


    func isMovementBlockedByBlockingLines(
        robotPose:
            RobotPose,

        command:
            RobotDriveCommand,

        blockingLines:
            [BlockingLine],

        predictionTime:
            Float = 0.10,

        additionalSafetyMargin:
            Float = 0
    ) -> Bool {

        guard blockingLines.isEmpty == false
        else {
            return false
        }


        let currentPosition =
            SIMD2<Float>(
                robotPose.position.x,
                robotPose.position.z
            )

        let predicted =
            predictedPosition(
                from:
                    robotPose,

                command:
                    command,

                predictionTime:
                    predictionTime
            )

        let minimumLineDistance =
            robotRadius
            +
            additionalSafetyMargin


        for line in blockingLines {

            let currentDistance =
                distanceToBlockingLine(
                    point:
                        currentPosition,

                    line:
                        line
                )

            let predictedDistance =
                distanceToBlockingLine(
                    point:
                        predicted,

                    line:
                        line
                )

            if predictedDistance < minimumLineDistance,
               predictedDistance < currentDistance {

                return true
            }
        }


        return false
    }


    func blockingObject(
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
    ) -> PlacedMapObject? {

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

                return object
            }
        }


        return nil
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


    private func distanceToBlockingLine(
        point:
            SIMD2<Float>,

        line:
            BlockingLine
    ) -> Float {

        guard line.points.count >= 2
        else {
            return .greatestFiniteMagnitude
        }


        var minimumDistance =
            Float.greatestFiniteMagnitude


        for index in
            0..<(line.points.count - 1) {

            let start =
                SIMD2<Float>(
                    line.points[index].x,
                    line.points[index].z
                )

            let end =
                SIMD2<Float>(
                    line.points[index + 1].x,
                    line.points[index + 1].z
                )

            minimumDistance =
                min(
                    minimumDistance,
                    distance(
                        from:
                            point,

                        toSegmentFrom:
                            start,

                        to:
                            end
                    )
                )
        }


        return minimumDistance
    }


    private func distance(
        from point:
            SIMD2<Float>,

        toSegmentFrom start:
            SIMD2<Float>,

        to end:
            SIMD2<Float>
    ) -> Float {

        let segment =
            end
            -
            start

        let lengthSquared =
            simd_length_squared(
                segment
            )

        guard lengthSquared > 0
        else {

            return simd_distance(
                point,
                start
            )
        }


        let t =
            max(
                0,
                min(
                    1,
                    simd_dot(
                        point
                        -
                        start,
                        segment
                    )
                    /
                    lengthSquared
                )
            )

        let nearest =
            start
            +
            segment
            *
            t


        return simd_distance(
            point,
            nearest
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
