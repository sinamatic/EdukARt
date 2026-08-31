//
//  GameMapView.swift
//  EdukARt-Rebuild
//
//  Displays a frozen game map and provides interaction
//  for editing game content such as the race track.
//
//  Unlike AprilTagMapView, this view does not use the
//  live AprilTagMapBuilder.
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

    var allowsObjectPlacement:
        Bool = false

    var backgroundColor:
        Color = .black

    var borderColor:
        Color = .white.opacity(0.7)

    var borderLineWidth:
        CGFloat = 1
    
    


    // MARK: - Settings

    private let mapPadding:
        CGFloat = 28

    private let minimumExtent:
        Float = 1.0

    private let tagSize:
        CGFloat = 24

    private let cornerRadius:
        CGFloat = 18

    private let rawTrackLineWidth:
        CGFloat = 5

    private let finalTrackLineWidth:
        CGFloat = 5


    // MARK: - Body

    var body: some View {

        GeometryReader { geometry in

            let layout =
                createLayout(
                    size:
                        geometry.size
                )


            ZStack {

                backgroundColor


                // ------------------------------------------
                // Track
                // ------------------------------------------

                trackLayer(
                    layout:
                        layout
                )
                
                // ------------------------------------------
                // Items / Obstacles
                // ------------------------------------------

                ForEach(
                    mapObjects
                ) { object in

                    mapObjectView(
                        object
                    )
                    .position(
                        mapToScreen(
                            x:
                                object.x,

                            z:
                                object.z,

                            layout:
                                layout
                        )
                    )
                }


                // ------------------------------------------
                // AprilTags
                // ------------------------------------------

                ForEach(
                    aprilTags
                ) { tag in

                    aprilTagView(
                        tag
                    )
                    .position(
                        mapToScreen(
                            x:
                                tag.x,

                            z:
                                tag.z,

                            layout:
                                layout
                        )
                    )
                }
            }
            .contentShape(
                Rectangle()
            )
            .gesture(
                allowsCourseDrawing
                ? drawingGesture(
                    layout:
                        layout
                )
                : nil
            )
            .dropDestination(
                for:
                    String.self
            ) { droppedValues, location in

                guard allowsObjectPlacement,
                      let rawValue =
                        droppedValues.first,
                      let type =
                        MapObjectType(
                            rawValue:
                                rawValue
                        )
                else {
                    return false
                }


                let mapPoint =
                    screenToMap(
                        location,
                        layout:
                            layout
                    )


                let object =
                    PlacedMapObject(
                        type:
                            type,

                        x:
                            mapPoint.x,

                        z:
                            mapPoint.y
                    )


                mapObjects.append(
                    object
                )


                print(
                    "# MAP OBJECT ADDED | \(type.name) | x \(mapPoint.x) | z \(mapPoint.y)"
                )


                return true
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    cornerRadius
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    cornerRadius
            )
            .stroke(
                borderColor,
                lineWidth:
                    borderLineWidth
            )
        }
    }


    // ======================================================
    // MARK: - Track Layer
    // ======================================================

    @ViewBuilder
    private func trackLayer(
        layout: MapLayout
    ) -> some View {

        // While the user is drawing, show the direct input.
        if allowsCourseDrawing,
           course.rawPoints.count >= 2 {

            Path { path in

                guard let first =
                    course.rawPoints.first
                else {
                    return
                }


                path.move(
                    to:
                        mapToScreen(
                            point:
                                first,

                            layout:
                                layout
                        )
                )


                for point in
                    course.rawPoints.dropFirst() {

                    path.addLine(
                        to:
                            mapToScreen(
                                point:
                                    point,

                                layout:
                                    layout
                            )
                    )
                }
            }
            .stroke(
                Color.white.opacity(0.35),
                style:
                    StrokeStyle(
                        lineWidth:
                            rawTrackLineWidth,

                        lineCap:
                            .round,

                        lineJoin:
                            .round
                    )
            )
        }


            // Final processed centerline
            // --------------------------------------------------
            //
            // The processed track consists of uniformly spaced
            // points in physical map coordinates.
            //
            // Each segment receives its own color so that the
            // track gradually changes from yellow at the start
            // to green at the end.
            // --------------------------------------------------

            if course.trackPoints.count >= 2 {

                let points =
                    course.trackPoints

                let segmentCount =
                    points.count - 1


                // --------------------------------------------------
                // Draw track segments
                // --------------------------------------------------

                ForEach(
                    0..<segmentCount,
                    id: \.self
                ) { index in

                    let progress =
                        CGFloat(index)
                        / CGFloat(
                            max(
                                segmentCount - 1,
                                1
                            )
                        )


                    Path { path in

                        path.move(
                            to:
                                mapToScreen(
                                    point:
                                        points[index],

                                    layout:
                                        layout
                                )
                        )


                        path.addLine(
                            to:
                                mapToScreen(
                                    point:
                                        points[index + 1],

                                    layout:
                                        layout
                                )
                        )
                    }
                    .stroke(
                        courseColor(
                            at:
                                progress
                        ),
                        style:
                            StrokeStyle(
                                lineWidth:
                                    finalTrackLineWidth,

                                lineCap:
                                    .round,

                                lineJoin:
                                    .round
                            )
                    )
                }


                // --------------------------------------------------
                // Start point
                // --------------------------------------------------

                if let start =
                    points.first {

                    Circle()
                        .fill(
                            Color.yellow
                        )
                        .frame(
                            width:
                                11,

                            height:
                                11
                        )
                        .position(
                            mapToScreen(
                                point:
                                    start,

                                layout:
                                    layout
                            )
                        )
                }


                // --------------------------------------------------
                // End point
                // --------------------------------------------------

                if let end =
                    points.last {

                    Circle()
                        .fill(
                            Color.green
                        )
                        .frame(
                            width:
                                11,

                            height:
                                11
                        )
                        .position(
                            mapToScreen(
                                point:
                                    end,

                                layout:
                                    layout
                            )
                        )
                }
            }
    }

    // MARK: - Course Color

    private func courseColor(
        at progress: CGFloat
    ) -> Color {

        Color(
            red:
                1 - progress,

            green:
                0.85
                + progress * 0.15,

            blue:
                0
        )
    }
    
    // ======================================================
    // MARK: - Map Object
    // ======================================================

    private func mapObjectView(
        _ object: PlacedMapObject
    ) -> some View {

        Text(
            object.type.symbol
        )
        .font(
            .system(
                size:
                    22
            )
        )
        .frame(
            width:
                30,

            height:
                30
        )
        .background(
            object.type.isObstacle
            ? Color.red.opacity(0.72)
            : Color.green.opacity(0.72)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    6,

                style:
                    .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    6,

                style:
                    .continuous
            )
            .stroke(
                .white.opacity(
                    0.42
                ),
                lineWidth:
                    1
            )
        }
        .rotationEffect(
            .radians(
                Double(
                    object.rotation
                )
            )
        )
    }


    // ======================================================
    // MARK: - Drawing Gesture
    // ======================================================

    private func drawingGesture(
        layout: MapLayout
    ) -> some Gesture {

        DragGesture(
            minimumDistance:
                0
        )
        .onChanged { value in

            let mapPoint =
                screenToMap(
                    value.location,
                    layout:
                        layout
                )


            // Start a completely new road when the
            // first point of a new gesture is received.
            if course.rawPoints.isEmpty {

                course.beginDrawing()
            }


            course.addRawPoint(
                x:
                    mapPoint.x,

                z:
                    mapPoint.y
            )
        }
        .onEnded { _ in

            course.finishDrawing()
        }
    }


    // ======================================================
    // MARK: - AprilTag
    // ======================================================

    private func aprilTagView(
        _ tag: StoredAprilTag
    ) -> some View {

        ZStack {

            Rectangle()
                .fill(
                    Color.black
                )


            Rectangle()
                .stroke(
                    tag.id == referenceTagID
                    ? Color.red
                    : Color.white,

                    lineWidth:
                        2
                )


            Text(
                "\(tag.id)"
            )
            .font(
                .caption2.bold()
            )
            .foregroundStyle(
                .white
            )
        }
        .frame(
            width:
                tagSize,

            height:
                tagSize
        )
        .rotationEffect(
            .radians(
                Double(
                    tag.rotation
                )
            )
        )
    }


    // ======================================================
    // MARK: - Coordinate Transformation
    // ======================================================

    private func createLayout(
        size: CGSize
    ) -> MapLayout {

        let realMinX =
            aprilTags
                .map { $0.x }
                .min()
            ?? 0

        let realMaxX =
            aprilTags
                .map { $0.x }
                .max()
            ?? 0

        let realMinZ =
            aprilTags
                .map { $0.z }
                .min()
            ?? 0

        let realMaxZ =
            aprilTags
                .map { $0.z }
                .max()
            ?? 0


        // --------------------------------------------------
        // Actual mapped size
        // --------------------------------------------------

        let realWidth =
            realMaxX
            - realMinX

        let realHeight =
            realMaxZ
            - realMinZ


        // --------------------------------------------------
        // Minimum visible map extent
        // --------------------------------------------------

        let width =
            max(
                realWidth,
                minimumExtent
            )

        let height =
            max(
                realHeight,
                minimumExtent
            )


        // --------------------------------------------------
        // Add artificial empty space symmetrically
        // --------------------------------------------------

        let extraX =
            (
                width
                - realWidth
            )
            / 2

        let extraZ =
            (
                height
                - realHeight
            )
            / 2


        let minX =
            realMinX
            - extraX

        let minZ =
            realMinZ
            - extraZ


        // --------------------------------------------------
        // Available screen area
        // --------------------------------------------------

        let usableWidth =
            max(
                size.width
                - mapPadding * 2,

                1
            )

        let usableHeight =
            max(
                size.height
                - mapPadding * 2,

                1
            )


        // X and Z use the same scale.
        let scale =
            min(
                usableWidth
                    / CGFloat(width),

                usableHeight
                    / CGFloat(height)
            )


        let contentWidth =
            CGFloat(width)
            * scale

        let contentHeight =
            CGFloat(height)
            * scale


        return MapLayout(
            minX:
                minX,

            minZ:
                minZ,

            width:
                width,

            height:
                height,

            scale:
                scale,

            offsetX:
                (
                    size.width
                    - contentWidth
                )
                / 2,

            offsetY:
                (
                    size.height
                    - contentHeight
                )
                / 2
        )
    }


    private func mapToScreen(
        point: SIMD2<Float>,
        layout: MapLayout
    ) -> CGPoint {

        mapToScreen(
            x:
                point.x,

            z:
                point.y,

            layout:
                layout
        )
    }


    private func mapToScreen(
        x: Float,
        z: Float,
        layout: MapLayout
    ) -> CGPoint {

        CGPoint(

            x:
                layout.offsetX
                +
                CGFloat(
                    x
                    - layout.minX
                )
                * layout.scale,

            y:
                layout.offsetY
                +
                CGFloat(
                    z
                    - layout.minZ
                )
                * layout.scale
        )
    }


    private func screenToMap(
        _ point: CGPoint,
        layout: MapLayout
    ) -> SIMD2<Float> {

        let x =
            layout.minX
            +
            Float(
                (
                    point.x
                    - layout.offsetX
                )
                / layout.scale
            )


        let z =
            layout.minZ
            +
            Float(
                (
                    point.y
                    - layout.offsetY
                )
                / layout.scale
            )


        return SIMD2<Float>(
            x,
            z
        )
    }
}


// MARK: - Map Layout

private struct MapLayout {

    let minX:
        Float

    let minZ:
        Float

    let width:
        Float

    let height:
        Float

    let scale:
        CGFloat

    let offsetX:
        CGFloat

    let offsetY:
        CGFloat
}
