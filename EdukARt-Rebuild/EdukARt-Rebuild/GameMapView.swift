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

    @Binding var blockingLines:
        [BlockingLine]

    var shitDots:
        [ShitDot] = []

    var allowsObjectPlacement:
        Bool = false

    var allowsBlockingLineDrawing:
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

    @State private var currentBlockingLine:
        [SIMD2<Float>] = []


    // MARK: - Body

    var body: some View {

        MapCanvasView(
            data:
                displayData,

            allowsCourseDrawing:
                allowsCourseDrawing,

            allowsObjectPlacement:
                allowsObjectPlacement,

            allowsBlockingLineDrawing:
                allowsBlockingLineDrawing,

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
                addObject,

            onAddBlockingLinePoint:
                addBlockingLinePoint,

            onFinishBlockingLineDrawing:
                finishBlockingLine
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

            blockingLines:
                blockingLines,

            currentBlockingLine:
                currentBlockingLine,

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

            let trigger =
                PlacedMapObject(
                    type:
                        .treeTrigger,
                    x:
                        point.x,
                    z:
                        point.y
                )

            let tree =
                PlacedMapObject(
                    type:
                        .tree,
                    x:
                        point.x,
                    z:
                        point.y
                        - treeSpawnOffset
                )

            mapObjects.append(
                trigger
            )

            mapObjects.append(
                tree
            )

            print(
                "# MAP OBJECT ADDED | Tree Trigger x \(point.x) | z \(point.y) | Tree x \(tree.x) | z \(tree.z)"
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


    // MARK: - Blocking Lines

    private func addBlockingLinePoint(
        _ point: SIMD2<Float>
    ) {

        guard allowsBlockingLineDrawing
        else {
            return
        }


        guard let last =
            currentBlockingLine.last
        else {

            currentBlockingLine.append(
                point
            )

            return
        }


        guard simd_distance(
            last,
            point
        ) >= 0.03
        else {
            return
        }


        currentBlockingLine.append(
            point
        )
    }


    private func finishBlockingLine() {

        guard currentBlockingLine.count >= 2
        else {

            currentBlockingLine.removeAll()

            return
        }


        let points =
            currentBlockingLine.map { point in

                BlockingLinePoint(
                    x:
                        point.x,

                    z:
                        point.y
                )
            }


        blockingLines.append(
            BlockingLine(
                points:
                    points
            )
        )


        currentBlockingLine.removeAll()
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

    @State private var blockingLines:
        [BlockingLine] = []

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

            blockingLines:
                $blockingLines,

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

        let blockingLineFingerprint =
            map.blockingLines.map { line in

                line.points.map {
                    "\($0.x):\($0.z)"
                }
                .joined(
                    separator:
                        ","
                )
            }
            .joined(
                separator:
                    "|"
            )


        return "\(map.id)-\(trackFingerprint)-\(objectFingerprint)-\(blockingLineFingerprint)"
    }


    // MARK: - Load

    private func loadMap() {

        course.load(
            storedTrackPoints:
                map.trackPoints
        )

        mapObjects =
            map.mapObjects

        blockingLines =
            map.blockingLines
    }
}
