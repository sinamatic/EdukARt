//
//  AprilTagLocalization.swift
//  EdukARt-Rebuild
//
//  AprilTag detection:
//  https://github.com/keyqcloud/SwiftAprilTag
//
//  AprilTag coordinate system:
//  https://github.com/AprilRobotics/apriltag
//
//  ARKit camera transform:
//  https://developer.apple.com/documentation/arkit/arcamera/transform
//

/// Localizes AprilTags within the EdukARt map coordinate system.
///
/// `AprilTagLocalization` estimates the world-space pose of detected AprilTags
/// by combining SwiftAprilTag pose estimation with the current ARKit camera
/// transform.
///
/// The smallest detected tag ID in the valid map range `1...40` is selected as
/// the map reference. Tag `0` is reserved for robot localization and is therefore
/// excluded from map localization.
///
/// The reference pose is calculated from multiple valid measurements and defines
/// the origin and horizontal orientation of the EdukARt 2D map. Once the reference
/// is established, detected map tags are expressed relative to this coordinate
/// system as an `AprilTagMapPose`.
///
/// Call `reset()` to discard the current reference and start a new localization.

import ARKit
import SwiftAprilTag
import simd


// MARK: - Map Pose

struct AprilTagMapPose {

    let id: Int

    let x: Float
    let z: Float

    let rotation: Float
    let height: Float

    let worldTransform: simd_float4x4
}


// MARK: - AprilTag Localization

final class AprilTagLocalization {

    let tagSize: Double


    // --------------------------------------------------
    // Valid map tags
    // --------------------------------------------------
    //
    // Tag 0 is reserved for robot localization.
    // The map may only use IDs 1...40.
    // --------------------------------------------------

    private let validMapTagIDs =
        1...40


    // --------------------------------------------------
    // Pose quality
    // --------------------------------------------------
    //
    // Smaller reprojection errors are better.
    // Values below 1.0 are typically clean poses.
    // --------------------------------------------------

    private let maximumReprojectionError:
        Float = 1.0

    private let maximumReferenceReprojectionError:
        Float = 0.35


    // --------------------------------------------------
    // Reference measurements
    // --------------------------------------------------

    private let requiredReferenceMeasurements =
        20

    private(set) var referenceTagID:
        Int?

    private var referenceMeasurements:
        [simd_float4x4] = []

    private var referenceTagWorldTransform:
        simd_float4x4?


    // MARK: - Map Reference World Transform

    var mapReferenceWorldTransform:
        simd_float4x4? {

        referenceTagWorldTransform
    }


    // --------------------------------------------------
    // Reference state
    // --------------------------------------------------

    private var isReferenceLocked: Bool {

        referenceTagWorldTransform != nil
    }


    // MARK: - Init

    init(
        tagSize: Double = 0.096
    ) {

        self.tagSize =
            tagSize
    }


    // MARK: - Set Reference Tag

    func setReferenceTag(
        id: Int
    ) {

        // Keep the currently selected reference
        // if it already matches.
        if referenceTagID == id {
            return
        }

        referenceTagID =
            id

        referenceTagWorldTransform =
            nil

        print(
            "# MAP REFERENCE SET | ID \(id)"
        )
    }


    // MARK: - Select Reference Tag

    func selectReferenceTag(
        from detections: [Detection]
    ) {

        // Keep the already selected reference.
        guard referenceTagID == nil
        else {
            return
        }


        // Only IDs 1...40 may define the map.
        let validDetections =
            detections.filter {
                validMapTagIDs.contains(
                    $0.id
                )
            }


        // Select the smallest currently visible ID.
        guard let smallestID =
            validDetections
                .map({ $0.id })
                .min()

        else {
            return
        }


        referenceTagID =
            smallestID


        print(
            "# MAP REFERENCE SELECTED | ID \(smallestID)"
        )
    }


    // MARK: - Localize Tag

    func localize(
        detection: Detection,
        frame: ARFrame,
        intrinsics: CameraIntrinsics
    ) -> AprilTagMapPose? {


        // --------------------------------------------------
        // 1. Check tag ID
        // --------------------------------------------------

        guard validMapTagIDs.contains(
            detection.id
        )
        else {

            print(
                "# TAG REJECTED | invalid ID \(detection.id)"
            )

            return nil
        }


        // --------------------------------------------------
        // 2. A reference tag must exist
        // --------------------------------------------------

        guard let referenceTagID
        else {
            return nil
        }


        // --------------------------------------------------
        // 3. Estimate pose relative to camera
        // --------------------------------------------------

        guard let pose =
            detection.estimatePose(
                intrinsics: intrinsics,
                tagSize: tagSize
            )

        else {
            return nil
        }


        // --------------------------------------------------
        // 4. Reject poor pose estimates
        // --------------------------------------------------

        guard pose.reprojectionError
                <= maximumReprojectionError

        else {

            print(
                String(
                    format:
                        "# TAG REJECTED | ID %d | reprojection error %.3f",
                    detection.id,
                    pose.reprojectionError
                )
            )

            return nil
        }


        // --------------------------------------------------
        // Additional quality filtering for reference tag
        // --------------------------------------------------
        //
        // The reference determines the complete orientation
        // of the saved map.
        //
        // Therefore we only collect particularly clean
        // measurements for the reference tag.
        // --------------------------------------------------

        if detection.id == referenceTagID {

            guard pose.reprojectionError
                    <= maximumReferenceReprojectionError
            else {

                print(
                    String(
                        format:
                            "# MAP REFERENCE SKIPPED | reprojection %.3f",
                        pose.reprojectionError
                    )
                )

                return nil
            }


            let cameraTagPosition =
                SIMD3<Float>(
                    pose.transform.columns.3.x,
                    pose.transform.columns.3.y,
                    pose.transform.columns.3.z
                )


            let cameraDistance =
                simd_length(
                    cameraTagPosition
                )


            // Reference tag should not be too far away.
            guard cameraDistance <= 1.20
            else {

                print(
                    String(
                        format:
                            "# MAP REFERENCE SKIPPED | distance %.2f m",
                        cameraDistance
                    )
                )

                return nil
            }
        }


        // --------------------------------------------------
        // 5. AprilTag camera -> ARKit camera
        // --------------------------------------------------

        let aprilTagToARKitCamera =
            simd_float4x4(
                diagonal:
                    SIMD4<Float>(
                        1,
                        -1,
                        -1,
                        1
                    )
            )


        // --------------------------------------------------
        // 6. Tag -> ARKit world
        // --------------------------------------------------

        let tagWorldTransform =
            frame.camera.transform
            * aprilTagToARKitCamera
            * pose.transform


        // --------------------------------------------------
        // 7. Build reference from multiple measurements
        // --------------------------------------------------

        if detection.id == referenceTagID {

            collectReferenceMeasurement(
                tagWorldTransform
            )
        }


        // --------------------------------------------------
        // 8. Wait until reference is locked
        // --------------------------------------------------

        guard let referenceTransform =
            referenceTagWorldTransform

        else {
            return nil
        }


        // --------------------------------------------------
        // 9. ARKit world -> EdukARt map
        // --------------------------------------------------

        let relativeTransform =
            simd_inverse(
                referenceTransform
            )
            * tagWorldTransform


        // --------------------------------------------------
        // 10. Map position
        // --------------------------------------------------
// Own April Tag Coordinate System
//        let mapX =
//            relativeTransform
//                .columns.3.x
//
//        let mapZ =
//            relativeTransform
//                .columns.3.y
//
//        let height =
//            relativeTransform
//                .columns.3.z
    
        // AR Kit Coordinate System
        let mapX =
            relativeTransform
                .columns.3.x

        let mapZ =
            relativeTransform
                .columns.3.z

        let height =
            relativeTransform
                .columns.3.y


        // --------------------------------------------------
        // 11. Map rotation
        // --------------------------------------------------

//        let tagXAxis =
//            relativeTransform
//                .columns.0
//
//        let rotation =
//            atan2(
//                tagXAxis.y,
//                tagXAxis.x
//            )

        let tagXAxis =
            relativeTransform
                .columns.0

        let rotation =
            atan2(
                tagXAxis.z,
                tagXAxis.x
            )

        return AprilTagMapPose(
            id: detection.id,
            x: mapX,
            z: mapZ,
            rotation: rotation,
            height: height,
            worldTransform: tagWorldTransform
        )
    }


    // MARK: - Localize Robot

    func localizeRobot(
        detection: Detection,
        frame: ARFrame,
        intrinsics: CameraIntrinsics,
        mapWorldTransform: simd_float4x4? = nil
    ) -> RobotPose? {

        // Tag 0 belongs to the physical Eduard.
        guard detection.id == 0
        else {
            return nil
        }


        // --------------------------------------------------
        // Estimate AprilTag #0 pose relative to camera
        // --------------------------------------------------

        guard let pose =
            detection.estimatePose(
                intrinsics: intrinsics,
                tagSize: tagSize
            )

        else {
            return nil
        }


        // --------------------------------------------------
        // Reject poor measurements
        // --------------------------------------------------

        guard pose.reprojectionError
                <= maximumReprojectionError

        else {

            print(
                String(
                    format:
                        "# ROBOT TAG REJECTED | error %.3f",
                    pose.reprojectionError
                )
            )

            return nil
        }


        // --------------------------------------------------
        // AprilTag camera coordinates -> ARKit coordinates
        // --------------------------------------------------

        let aprilTagToARKitCamera =
            simd_float4x4(
                diagonal:
                    SIMD4<Float>(
                        1,
                        -1,
                        -1,
                        1
                    )
            )


        // --------------------------------------------------
        // Robot tag -> ARKit world
        // --------------------------------------------------

        let robotWorldTransform =
            frame.camera.transform
            * aprilTagToARKitCamera
            * pose.transform


        // --------------------------------------------------
        // Choose map coordinate system
        // --------------------------------------------------
        //
        // During normal gameplay we prefer the current
        // multi-tag stabilized map transform.
        //
        // Before that exists, fall back to the original
        // reference-tag transform.
        // --------------------------------------------------

        guard let mapTransform =
            mapWorldTransform
            ?? referenceTagWorldTransform

        else {
            return nil
        }


        // --------------------------------------------------
        // ARKit world -> map coordinates
        // --------------------------------------------------

        let relativeTransform =
            simd_inverse(
                mapTransform
            )
            * robotWorldTransform


        let mapX =
            relativeTransform
                .columns.3.x

        let mapZ =
            relativeTransform
                .columns.3.z


        // --------------------------------------------------
        // Robot rotation
        // --------------------------------------------------

        let robotXAxis =
            relativeTransform
                .columns.0

        let rotation =
            atan2(
                robotXAxis.z,
                robotXAxis.x
            )


        return RobotPose(
            position:
                SIMD3<Float>(
                    mapX,
                    0,
                    mapZ
                ),
            rotation:
                rotation
        )
    }

    // MARK: - Collect Reference Measurement

    private func collectReferenceMeasurement(
        _ transform:
            simd_float4x4
    ) {

        // Once locked, the reference never changes.
        guard isReferenceLocked == false
        else {
            return
        }


        // --------------------------------------------------
        // Convert every individual measurement into a
        // horizontal map transform BEFORE averaging.
        // --------------------------------------------------

        let flattenedTransform =
            makeMapReferenceTransform(
                from:
                    transform
            )


        let horizontalTransform =
            makeMapReferenceTransform(
                from:
                    flattenedTransform
            )

        referenceMeasurements.append(
            horizontalTransform
        )


        print(
            "# MAP REFERENCE MEASUREMENT \(referenceMeasurements.count)/\(requiredReferenceMeasurements)"
        )


        guard referenceMeasurements.count
                >= requiredReferenceMeasurements

        else {
            return
        }


        // --------------------------------------------------
        // Average position + horizontal rotation.
        // --------------------------------------------------

        let averagedTransform =
            averageTransform(
                referenceMeasurements
            )

        referenceTagWorldTransform =
            averagedTransform


        referenceMeasurements
            .removeAll()


        print(
            "# MAP REFERENCE LOCKED | ID \(referenceTagID ?? -1)"
        )
    }


    // MARK: - Average Reference Transform

    private func averageTransform(
        _ transforms:
            [simd_float4x4]
    ) -> simd_float4x4 {

        var position =
            SIMD3<Float>.zero

        var sineSum:
            Float = 0

        var cosineSum:
            Float = 0


        for transform in transforms {

            position +=
                SIMD3<Float>(
                    transform.columns.3.x,
                    transform.columns.3.y,
                    transform.columns.3.z
                )


            let xAxis =
                transform.columns.0

            let yaw =
                atan2(
                    xAxis.z,
                    xAxis.x
                )

            sineSum +=
                sin(yaw)

            cosineSum +=
                cos(yaw)
        }


        position /=
            Float(
                transforms.count
            )


        let yaw =
            atan2(
                sineSum,
                cosineSum
            )


        let xAxis =
            SIMD3<Float>(
                cos(yaw),
                0,
                sin(yaw)
            )

        let yAxis =
            SIMD3<Float>(
                0,
                1,
                0
            )

        let zAxis =
            simd_normalize(
                simd_cross(
                    xAxis,
                    yAxis
                )
            )


        return simd_float4x4(
            columns: (

                SIMD4<Float>(
                    xAxis.x,
                    xAxis.y,
                    xAxis.z,
                    0
                ),

                SIMD4<Float>(
                    yAxis.x,
                    yAxis.y,
                    yAxis.z,
                    0
                ),

                SIMD4<Float>(
                    zAxis.x,
                    zAxis.y,
                    zAxis.z,
                    0
                ),

                SIMD4<Float>(
                    position.x,
                    position.y,
                    position.z,
                    1
                )
            )
        )
    }
    
    // MARK: - Create Map Reference Transform

    private func makeMapReferenceTransform(
        from transform: simd_float4x4
    ) -> simd_float4x4 {

        // --------------------------------------------------
        // Position of the reference tag
        // --------------------------------------------------

        let position =
            SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )


        // --------------------------------------------------
        // Horizontal X direction
        // --------------------------------------------------
        //
        // Take the X axis of the AprilTag,
        // but remove its vertical component.
        //
        // This keeps the map rotation while ignoring
        // small measured tilts of the reference tag.
        // --------------------------------------------------

        var xAxis =
            SIMD3<Float>(
                transform.columns.0.x,
                0,
                transform.columns.0.z
            )


        // Normalize to a unit vector.
        xAxis =
            simd_normalize(
                xAxis
            )


        // --------------------------------------------------
        // Vertical map axis
        // --------------------------------------------------
        //
        // ARKit world tracking uses Y as the vertical axis.
        // The map therefore always uses the ARKit up axis.
        // --------------------------------------------------

        let yAxis =
            SIMD3<Float>(
                0,
                1,
                0
            )


        // --------------------------------------------------
        // Horizontal Z direction
        // --------------------------------------------------

        let zAxis =
            simd_normalize(
                simd_cross(
                    xAxis,
                    yAxis
                )
            )


        // --------------------------------------------------
        // Create map reference transform
        // --------------------------------------------------

        return simd_float4x4(
            columns: (
                SIMD4<Float>(
                    xAxis.x,
                    xAxis.y,
                    xAxis.z,
                    0
                ),

                SIMD4<Float>(
                    yAxis.x,
                    yAxis.y,
                    yAxis.z,
                    0
                ),

                SIMD4<Float>(
                    zAxis.x,
                    zAxis.y,
                    zAxis.z,
                    0
                ),

                SIMD4<Float>(
                    position.x,
                    position.y,
                    position.z,
                    1
                )
            )
        )
    }


    // MARK: - Reset

    func reset() {

        referenceTagID =
            nil

        referenceMeasurements.removeAll()

        referenceTagWorldTransform =
            nil


        print(
            "# MAP REFERENCE RESET"
        )
    }
}
