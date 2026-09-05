//
//  AprilTagMapBuilder.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 23.08.26.
//  Builds a stable 2D map from AprilTag measurements.
//

import Foundation
import simd
import Combine


// MARK: - Stored Map Tag

struct AprilTagMapPoint: Identifiable {

    let id: Int

    // Position in the 2D map
    let x: Float
    let z: Float

    // Rotation in the map plane
    let rotation: Float

    // True for the tag that defines the map origin
    let isReference: Bool
}


// MARK: - AprilTag Map Builder

final class AprilTagMapBuilder: ObservableObject {

    // --------------------------------------------------
    // Settings
    // --------------------------------------------------

    // Number of measurements used for one map point.
    private let requiredMeasurements =
        10

    // New tags should normally be no more than
    // about 2 metres away from an already mapped tag.
    private let maximumNeighborDistance:
        Float = 3.0


    // --------------------------------------------------
    // Reference
    // --------------------------------------------------

    private(set) var referenceTagID:
        Int?


    // --------------------------------------------------
    // Finished map points
    // --------------------------------------------------

    @Published private(set) var mapPoints:
        [AprilTagMapPoint] = []


    // --------------------------------------------------
    // Measurements that are still being collected
    // --------------------------------------------------

    private var measurements:
        [Int: [AprilTagMapPose]] = [:]


    // MARK: - Set Reference

    func setReferenceTag(
        id: Int
    ) {

        // Reference must only be set once.
        guard referenceTagID == nil
        else {
            return
        }


        referenceTagID =
            id


        // The reference defines the origin
        // of the complete 2D map.
        let referencePoint =
            AprilTagMapPoint(
                id: id,
                x: 0,
                z: 0,
                rotation: 0,
                isReference: true
            )


        mapPoints.append(
            referencePoint
        )


        print(
            "# MAP BUILDER REFERENCE | ID \(id)"
        )
    }


    // MARK: - Add Measurement

    func add(
        pose: AprilTagMapPose
    ) {

        // --------------------------------------------------
        // A reference tag must exist first
        // --------------------------------------------------

        guard let referenceTagID
        else {
            return
        }


        // --------------------------------------------------
        // Reference is already stored as (0, 0)
        // --------------------------------------------------

        guard pose.id != referenceTagID
        else {
            return
        }


        // --------------------------------------------------
        // Ignore tags that are already finished
        // --------------------------------------------------

        guard mapPoints.contains(
            where: {
                $0.id == pose.id
            }
        ) == false

        else {
            return
        }


        // --------------------------------------------------
        // Check whether the new tag is close enough
        // to an already known map point.
        // --------------------------------------------------

        guard isNearKnownTag(
            pose
        )
        else {

            print(
                "# MAP BUILDER WAITING | ID \(pose.id) has no known neighbour within \(maximumNeighborDistance) m"
            )

            return
        }


        // --------------------------------------------------
        // Store measurement
        // --------------------------------------------------

        measurements[
            pose.id,
            default: []
        ].append(
            pose
        )


        let measurementCount =
            measurements[
                pose.id
            ]?.count ?? 0


        print(
            "# MAP BUILDER MEASUREMENT | ID \(pose.id) | \(measurementCount)/\(requiredMeasurements)"
        )


        // --------------------------------------------------
        // Wait for enough measurements
        // --------------------------------------------------

        guard measurementCount
                >= requiredMeasurements

        else {
            return
        }


        // --------------------------------------------------
        // Create final map point
        // --------------------------------------------------

        createMapPoint(
            for: pose.id
        )
    }


    // MARK: - Create Map Point

    private func createMapPoint(
        for id: Int
    ) {

        guard let poses =
            measurements[id]
        else {
            return
        }


        guard poses.isEmpty == false
        else {
            return
        }


        // --------------------------------------------------
        // Average X
        // --------------------------------------------------

        let x =
            poses
                .map {
                    $0.x
                }
                .reduce(
                    0,
                    +
                )
            / Float(
                poses.count
            )


        // --------------------------------------------------
        // Average Z
        // --------------------------------------------------

        let z =
            poses
                .map {
                    $0.z
                }
                .reduce(
                    0,
                    +
                )
            / Float(
                poses.count
            )


        // --------------------------------------------------
        // Average rotation
        // --------------------------------------------------
        //
        // Angles cannot simply be averaged normally.
        //
        // Example:
        //
        // +179°
        // -179°
        //
        // The result should be about 180°,
        // not 0°.
        // --------------------------------------------------

        let rotation =
            averageRotation(
                poses.map {
                    $0.rotation
                }
            )


        // --------------------------------------------------
        // Store final point
        // --------------------------------------------------

        let point =
            AprilTagMapPoint(
                id: id,
                x: x,
                z: z,
                rotation: rotation,
                isReference: false
            )


        mapPoints.append(
            point
        )


        // Measurements are no longer required.
        measurements[
            id
        ] = nil


        print(
            String(
                format:
                    "# MAP BUILDER TAG SAVED | ID %d | X %.3f | Z %.3f | Rotation %.2f°",
                id,
                x,
                z,
                rotation * 180 / .pi
            )
        )
    }


    // MARK: - Check Neighbor Distance

    private func isNearKnownTag(
        _ pose: AprilTagMapPose
    ) -> Bool {

        // The reference already exists when this function
        // is called, so mapPoints cannot normally be empty.
        guard mapPoints.isEmpty == false
        else {
            return false
        }


        for point in mapPoints {

            let xDifference =
                pose.x - point.x

            let zDifference =
                pose.z - point.z


            let distance =
                sqrt(
                    xDifference * xDifference
                    +
                    zDifference * zDifference
                )


            if distance
                <= maximumNeighborDistance {

                return true
            }
        }


        return false
    }


    // MARK: - Average Rotation

    private func averageRotation(
        _ rotations: [Float]
    ) -> Float {

        guard rotations.isEmpty == false
        else {
            return 0
        }


        var sineSum:
            Float = 0

        var cosineSum:
            Float = 0


        for rotation in rotations {

            sineSum +=
                sin(
                    rotation
                )

            cosineSum +=
                cos(
                    rotation
                )
        }


        return atan2(
            sineSum,
            cosineSum
        )
    }
    
    // MARK: - Create Game Map

    func createGameMap(
        name: String
    ) -> GameMap? {

        // A map cannot be saved without a reference tag.
        guard let referenceTagID
        else {
            return nil
        }

        // Convert the temporary AprilTag map points
        // into persistent map data.
        let storedTags =
            mapPoints.map { point in

                StoredAprilTag(
                    id:
                        point.id,

                    x:
                        point.x,

                    z:
                        point.z,

                    rotation:
                        point.rotation
                )
            }

        return GameMap(
            name:
                name,

            referenceTagID:
                referenceTagID,

            aprilTags:
                storedTags
        )
    }


    // MARK: - Reset

    func reset() {

        referenceTagID =
            nil

        mapPoints.removeAll()

        measurements.removeAll()


        print(
            "# MAP BUILDER RESET"
        )
    }
}
