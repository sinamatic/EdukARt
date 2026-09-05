//
//  GameMapView.swift
//  EdukARt-Rebuild
//
//  Displays a frozen game map and provides interaction
//  for editing game content such as the race track.
//

import SwiftUI
import simd


// MARK: - Game Map View

struct GameMapView: View {

    let aprilTags:
        [StoredAprilTag]

    let referenceTagID:
        Int

    @ObservedObject var course:
        Course

    var allowsCourseDrawing:
        Bool = false

    @Binding var mapObjects:
        [PlacedMapObject]

    var shitDots:
        [ShitDot] = []

    var allowsObjectPlacement:
        Bool = false

    var robotPose:
        RobotPose? = nil

    var simulationPose:
        RobotPose? = nil

    var backgroundColor:
        Color = .black.opacity(0.35)

    var borderColor:
        Color = .white.opacity(0.7)

    var borderLineWidth:
        CGFloat = 1

    private let treeSpawnOffset:
        Float = 1.0 // ToDo: position

    private struct TrackProjection {

        let point:
            SIMD2<Float>

        let distanceAlongTrack:
            Float
    }


    // MARK: - Body

    var body: some View {

        MapCanvasView(
            data:
                displayData,

            allowsCourseDrawing:
                allowsCourseDrawing,

            allowsObjectPlacement:
                allowsObjectPlacement,

            backgroundColor:
                backgroundColor,

            borderColor:
                borderColor,

            borderLineWidth:
                borderLineWidth,

            onAddRawPoint:
                addRawPoint,

            onFinishDrawing:
                finishDrawing,

            onAddObject:
                addObject
        )
    }


    // MARK: - Display Data

    private var displayData:
        MapDisplayData {

        MapDisplayData(
            aprilTags:
                aprilTags.map { tag in

                    MapDisplayTag(
                        id:
                            tag.id,
                        x:
                            tag.x,
                        z:
                            tag.z,
                        rotation:
                            tag.rotation,
                        isReference:
                            tag.id == referenceTagID
                    )
                },

            referenceTagID:
                referenceTagID,

            rawTrackPoints:
                allowsCourseDrawing
                ? course.rawPoints
                : [],

            trackPoints:
                course.trackPoints,

            mapObjects:
                mapObjects,

            shitDots:
                shitDots,

            robotPose:
                robotPose,

            simulationPose:
                simulationPose
        )
    }


    // MARK: - Drawing

    private func addRawPoint(
        _ point: SIMD2<Float>
    ) {

        guard allowsCourseDrawing
        else {
            return
        }


        if course.rawPoints.isEmpty {

            course.beginDrawing()
        }


        course.addRawPoint(
            x:
                point.x,
            z:
                point.y
        )
    }


    private func finishDrawing() {

        guard allowsCourseDrawing
        else {
            return
        }


        course.finishDrawing()
    }


    // MARK: - Objects

    private func addObject(
        type: MapObjectType,
        point: SIMD2<Float>
    ) {

        guard allowsObjectPlacement
        else {
            return
        }


        if type == .tree {

            let treePlacement =
                treePlacement(
                    for:
                        point
                )

            let trigger =
                PlacedMapObject(
                    type:
                        .treeTrigger,
                    x:
                        treePlacement.trigger.x,
                    z:
                        treePlacement.trigger.y,
                    rotation:
                        treePlacement.rotation
                )

            let tree =
                PlacedMapObject(
                    type:
                        .tree,
                    x:
                        treePlacement.tree.x,
                    z:
                        treePlacement.tree.y,
                    rotation:
                        treePlacement.rotation
                )

            mapObjects.append(
                trigger
            )

            mapObjects.append(
                tree
            )

            print(
                "# MAP OBJECT ADDED | Tree Trigger x \(trigger.x) | z \(trigger.z) | Tree x \(tree.x) | z \(tree.z) | rotation \(tree.rotation)"
            )

            return
        }


        let object =
            PlacedMapObject(
                type:
                    type,
                x:
                    point.x,
                z:
                    point.y
            )


        mapObjects.append(
            object
        )


        print(
            "# MAP OBJECT ADDED | \(type.name) | x \(point.x) | z \(point.y)"
        )
    }


    private func treePlacement(
        for point:
            SIMD2<Float>
    ) -> (
        trigger: SIMD2<Float>,
        tree: SIMD2<Float>,
        rotation: Float
    ) {

        guard let projection =
            projectedTrackPoint(
                nearest:
                    point
            )
        else {

            let fallbackTree =
                SIMD2<Float>(
                    point.x,
                    point.y
                    - treeSpawnOffset
                )

            return (
                trigger:
                    point,
                tree:
                    fallbackTree,
                rotation:
                    0
            )
        }

        let totalTrackLength =
            trackLength()

        let forwardDistance =
            projection.distanceAlongTrack
            +
            treeSpawnOffset

        let treePoint:
            SIMD2<Float>

        if forwardDistance <= totalTrackLength,
           let sampledPoint =
            trackPoint(
                atDistance:
                    forwardDistance
            ) {

            treePoint =
                sampledPoint

        } else if let sampledPoint =
            trackPoint(
                atDistance:
                    max(
                        projection.distanceAlongTrack
                        -
                        treeSpawnOffset,
                        0
                    )
            ) {

            treePoint =
                sampledPoint

        } else {

            treePoint =
                projection.point
                +
                SIMD2<Float>(
                    0,
                    -treeSpawnOffset
                )
        }

        return (
            trigger:
                projection.point,
            tree:
                treePoint,
            rotation:
                quantizedTreeRotation(
                    from:
                        projection.point,
                    to:
                        treePoint
                )
        )
    }


    private func projectedTrackPoint(
        nearest point:
            SIMD2<Float>
    ) -> TrackProjection? {

        let points =
            trackMapPoints()

        guard points.count >= 2
        else {
            return nil
        }

        var bestProjection:
            TrackProjection?

        var bestDistanceSquared =
            Float.greatestFiniteMagnitude

        var distanceBeforeSegment:
            Float = 0

        for index in 0..<(points.count - 1) {

            let start =
                points[index]

            let end =
                points[index + 1]

            let segment =
                end - start

            let segmentLengthSquared =
                simd_length_squared(
                    segment
                )

            guard segmentLengthSquared > 0.000001
            else {
                continue
            }

            let t =
                max(
                    0,
                    min(
                        1,
                        simd_dot(
                            point - start,
                            segment
                        )
                        /
                        segmentLengthSquared
                    )
                )

            let projectedPoint =
                start
                +
                segment
                *
                t

            let distanceSquared =
                simd_length_squared(
                    point - projectedPoint
                )

            if distanceSquared < bestDistanceSquared {

                bestDistanceSquared =
                    distanceSquared

                bestProjection =
                    TrackProjection(
                        point:
                            projectedPoint,
                        distanceAlongTrack:
                            distanceBeforeSegment
                            +
                            sqrt(
                                segmentLengthSquared
                            )
                            *
                            t
                    )
            }

            distanceBeforeSegment +=
                sqrt(
                    segmentLengthSquared
                )
        }

        return bestProjection
    }


    private func trackPoint(
        atDistance targetDistance:
            Float
    ) -> SIMD2<Float>? {

        let points =
            trackMapPoints()

        guard let first =
            points.first
        else {
            return nil
        }

        guard points.count >= 2
        else {
            return first
        }

        var distanceBeforeSegment:
            Float = 0

        for index in 0..<(points.count - 1) {

            let start =
                points[index]

            let end =
                points[index + 1]

            let segment =
                end - start

            let segmentLength =
                simd_length(
                    segment
                )

            guard segmentLength > 0.001
            else {
                continue
            }

            if distanceBeforeSegment + segmentLength >= targetDistance {

                let t =
                    max(
                        0,
                        min(
                            1,
                            (
                                targetDistance
                                -
                                distanceBeforeSegment
                            )
                            /
                            segmentLength
                        )
                    )

                return start
                +
                segment
                *
                t
            }

            distanceBeforeSegment +=
                segmentLength
        }

        return points.last
    }


    private func trackLength() -> Float {

        let points =
            trackMapPoints()

        guard points.count >= 2
        else {
            return 0
        }

        var length:
            Float = 0

        for index in 0..<(points.count - 1) {

            length +=
                simd_distance(
                    points[index],
                    points[index + 1]
                )
        }

        return length
    }


    private func quantizedTreeRotation(
        from trigger:
            SIMD2<Float>,
        to tree:
            SIMD2<Float>
    ) -> Float {

        let direction =
            tree - trigger

        guard simd_length_squared(
            direction
        ) > 0.000001
        else {
            return 0
        }

        let axis:
            SIMD2<Float>

        if abs(
            direction.x
        ) > abs(
            direction.y
        ) {

            axis =
                SIMD2<Float>(
                    direction.x >= 0
                    ? 1
                    : -1,
                    0
                )

        } else {

            axis =
                SIMD2<Float>(
                    0,
                    direction.y >= 0
                    ? 1
                    : -1
                )
        }

        return atan2(
            axis.x,
            -axis.y
        )
    }


    private func trackMapPoints() -> [SIMD2<Float>] {

        course.trackPoints.map { point in

            SIMD2<Float>(
                point.x,
                point.y
            )
        }
    }
}


// MARK: - Stored Game Map View

struct StoredGameMapView: View {

    let map:
        GameMap

    var robotPose:
        RobotPose? = nil

    var simulationPose:
        RobotPose? = nil

    var runtimeMapObjects:
        [PlacedMapObject]? = nil

    var shitDots:
        [ShitDot] = []

    var backgroundColor:
        Color = .black.opacity(0.5)

    var borderColor:
        Color = .white.opacity(0.7)

    var borderLineWidth:
        CGFloat = 1

    @StateObject private var course =
        Course()

    @State private var mapObjects:
        [PlacedMapObject] = []

    var body: some View {

        GameMapView(
            aprilTags:
                map.aprilTags,

            referenceTagID:
                map.referenceTagID,

            course:
                course,

            allowsCourseDrawing:
                false,

            mapObjects:
                Binding(
                    get: {
                        runtimeMapObjects
                        ?? mapObjects
                    },

                    set: { newValue in
                        mapObjects =
                            newValue
                    }
                ),

            shitDots:
                shitDots,

            allowsObjectPlacement:
                false,

            robotPose:
                robotPose,

            simulationPose:
                simulationPose,

            backgroundColor:
                backgroundColor,

            borderColor:
                borderColor,

            borderLineWidth:
                borderLineWidth
        )
        .onAppear {
            loadMap()
        }
        .onChange(
            of:
                mapFingerprint
        ) { _, _ in
            loadMap()
        }
    }


    // MARK: - Fingerprint

    private var mapFingerprint:
        String {

        let trackFingerprint =
            map.trackPoints.map {
                "\($0.x):\($0.z)"
            }
            .joined(
                separator:
                    "|"
            )

        let objectFingerprint =
            map.mapObjects.map {
                "\($0.id):\($0.type.rawValue):\($0.x):\($0.z):\($0.rotation)"
            }
            .joined(
                separator:
                    "|"
            )

        return "\(map.id)-\(trackFingerprint)-\(objectFingerprint)"
    }


    // MARK: - Load

    private func loadMap() {

        course.load(
            storedTrackPoints:
                map.trackPoints
        )

        mapObjects =
            map.mapObjects

    }
}
