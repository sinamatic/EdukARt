//
//  MapCanvasView.swift
//  EdukARt-Rebuild
//
//  Shared 2D renderer for live, stored and runtime map previews.
//

import SwiftUI
import simd


// MARK: - Map Display Data

struct MapDisplayData {

    var aprilTags:
        [MapDisplayTag]

    var referenceTagID:
        Int?

    var rawTrackPoints:
        [SIMD2<Float>] = []

    var trackPoints:
        [SIMD2<Float>] = []

    var mapObjects:
        [PlacedMapObject] = []

    var shitDots:
        [ShitDot] = []

    var robotPose:
        RobotPose?

    var simulationPose:
        RobotPose?
}


// MARK: - Map Display Tag

struct MapDisplayTag:
    Identifiable {

    let id:
        Int

    let x:
        Float

    let z:
        Float

    let rotation:
        Float

    let isReference:
        Bool
}


// MARK: - Map Canvas View

struct MapCanvasView: View {

    let data:
        MapDisplayData

    var allowsCourseDrawing:
        Bool = false

    var allowsObjectPlacement:
        Bool = false

    var backgroundColor:
        Color = .black.opacity(0.35)

    var borderColor:
        Color = .white.opacity(0.7)

    var borderLineWidth:
        CGFloat = 1

    var emptyText:
        String?

    var onAddRawPoint:
        ((SIMD2<Float>) -> Void)?

    var onFinishDrawing:
        (() -> Void)?

    var onAddObject:
        ((MapObjectType, SIMD2<Float>) -> Void)?


    // MARK: - Settings

    private let designCanvasSize:
        CGFloat = 360

    private let mapPadding:
        CGFloat = 28

    private let minimumMapPadding:
        CGFloat = 8

    private let mapPaddingScale:
        CGFloat = 0.16

    private let mapWorldPadding:
        Float = 0.25

    private let minimumExtent:
        Float = 1.0

    private let singleTagForwardExtent:
        Float = 3.0

    private let meaningfulExtentThreshold:
        Float = 1.0

    /// Minimum distance from the reference tag
    /// to the upper edge while drawing a course.
    private let minimumForwardDrawingDistance:
        Float = 3.0

    /// Small amount of space behind the reference tag.
    ///
    /// The map must not grow further in this direction
    /// when the user draws the course.
    private let drawingBackMargin:
        Float = 0.30

    private let tagSize:
        CGFloat = 24

    private let tagFontSize:
        CGFloat = 10

    private let cornerRadius:
        CGFloat = 18

    private let rawTrackLineWidth:
        CGFloat = 5

    private let finalTrackLineWidth:
        CGFloat = 5

    private let startEndPointSize:
        CGFloat = 11

    private let objectSymbolSize:
        CGFloat = 22

    private let objectFrameSize:
        CGFloat = 30

    private let objectCornerRadius:
        CGFloat = 6

    private let robotSize:
        CGFloat = 20


    // MARK: - Body

    var body: some View {

        GeometryReader { geometry in

            let layout =
                MapCanvasLayout(
                    data:
                        data,
                    size:
                        geometry.size,
                    mapPadding:
                        mapPadding,
                    minimumMapPadding:
                        minimumMapPadding,
                    mapPaddingScale:
                        mapPaddingScale,
                    mapWorldPadding:
                        mapWorldPadding,
                    minimumExtent:
                        minimumExtent,
                    singleTagForwardExtent:
                        singleTagForwardExtent,
                    meaningfulExtentThreshold:
                        meaningfulExtentThreshold,
                    allowsCourseDrawing:
                        allowsCourseDrawing,
                    minimumForwardDrawingDistance:
                        minimumForwardDrawingDistance,
                    drawingBackMargin:
                        drawingBackMargin,
                    designCanvasSize:
                        designCanvasSize
                )


            ZStack {

                backgroundColor


                if data.aprilTags.isEmpty,
                   let emptyText {

                    Text(
                        emptyText
                    )
                    .foregroundStyle(
                        .white
                    )
                    .font(
                        .caption
                    )

                } else {

                    mapContent(
                        layout:
                            layout
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
                    layout.screenToMap(
                        location
                    )


                onAddObject?(
                    type,
                    mapPoint
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


    // MARK: - Map Content

    private func mapContent(
        layout: MapCanvasLayout
    ) -> some View {

        ZStack {

            rawTrackLayer(
                layout:
                    layout
            )

            finalTrackLayer(
                layout:
                    layout
            )

            shitDotsLayer(
                layout:
                    layout
            )

            objectsLayer(
                layout:
                    layout
            )

            aprilTagsLayer(
                layout:
                    layout
            )

            robotLayer(
                layout:
                    layout
            )
        }
    }


    // MARK: - Track Layers

    @ViewBuilder
    private func rawTrackLayer(
        layout: MapCanvasLayout
    ) -> some View {

        if data.rawTrackPoints.count >= 2 {

            Path { path in

                guard let first =
                    data.rawTrackPoints.first
                else {
                    return
                }


                path.move(
                    to:
                        layout.mapToScreen(
                            first
                        )
                )


                for point in
                    data.rawTrackPoints.dropFirst() {

                    path.addLine(
                        to:
                            layout.mapToScreen(
                                point
                            )
                    )
                }
            }
            .stroke(
                Color.white.opacity(0.35),
                style:
                    StrokeStyle(
                        lineWidth:
                            rawTrackLineWidth
                            * layout.visualScale,
                        lineCap:
                            .round,
                        lineJoin:
                            .round
                    )
            )
        }
    }


    @ViewBuilder
    private func finalTrackLayer(
        layout: MapCanvasLayout
    ) -> some View {

        if data.trackPoints.count >= 2 {

            let points =
                data.trackPoints

            let segmentCount =
                points.count - 1


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
                            layout.mapToScreen(
                                points[index]
                            )
                    )


                    path.addLine(
                        to:
                            layout.mapToScreen(
                                points[index + 1]
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
                                finalTrackLineWidth
                                * layout.visualScale,
                            lineCap:
                                .round,
                            lineJoin:
                                .round
                        )
                )
            }


            if let start =
                points.first {

                Circle()
                    .fill(
                        Color.yellow
                    )
                    .frame(
                        width:
                            startEndPointSize
                            * layout.visualScale,
                        height:
                            startEndPointSize
                            * layout.visualScale
                    )
                    .position(
                        layout.mapToScreen(
                            start
                        )
                    )
            }


            if let end =
                points.last {

                Circle()
                    .fill(
                        Color.green
                    )
                    .frame(
                        width:
                            startEndPointSize
                            * layout.visualScale,
                        height:
                            startEndPointSize
                            * layout.visualScale
                    )
                    .position(
                        layout.mapToScreen(
                            end
                        )
                    )
            }
        }
    }


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


    // MARK: - Runtime Layers

    @ViewBuilder
    private func shitDotsLayer(
        layout: MapCanvasLayout
    ) -> some View {

        ForEach(
            data.shitDots
        ) { dot in

            Circle()
                .fill(
                    Color.brown
                )
                .frame(
                    width:
                        max(
                            CGFloat(
                                dot.radius * 2
                            )
                            * layout.scale,
                            2
                        ),
                    height:
                        max(
                            CGFloat(
                                dot.radius * 2
                            )
                            * layout.scale,
                            2
                        )
                )
                .position(
                    layout.mapToScreen(
                        x:
                            dot.position.x,
                        z:
                            dot.position.y
                    )
                )
        }
    }


    @ViewBuilder
    private func robotLayer(
        layout: MapCanvasLayout
    ) -> some View {

        if let robotPose =
            data.robotPose {

            robotPoseView(
                robotPose,
                color:
                    .blue,
                label:
                    "0",
                layout:
                    layout
            )
            .position(
                layout.mapToScreen(
                    x:
                        robotPose.position.x,
                    z:
                        robotPose.position.z
                )
            )
        }


        if let simulationPose =
            data.simulationPose {

            robotPoseView(
                simulationPose,
                color:
                    .cyan,
                label:
                    "3D",
                layout:
                    layout,
                isRotationReversed:
                    true
            )
            .position(
                layout.mapToScreen(
                    x:
                        simulationPose.position.x,
                    z:
                        simulationPose.position.z
                )
            )
        }
    }


    // MARK: - Objects

    private func objectsLayer(
        layout: MapCanvasLayout
    ) -> some View {

        ForEach(
            data.mapObjects
        ) { object in

            mapObjectView(
                object,
                layout:
                    layout
            )
            .position(
                layout.mapToScreen(
                    x:
                        object.x,
                    z:
                        object.z
                )
            )
        }
    }


    @ViewBuilder
    private func mapObjectView(
        _ object: PlacedMapObject,
        layout: MapCanvasLayout
    ) -> some View {

        if object.type == .tree {

            Circle()
                .fill(
                    Color.green
                )
                .frame(
                    width:
                        tagSize
                        * 0.5
                        * layout.visualScale,
                    height:
                        tagSize
                        * 0.5
                        * layout.visualScale
                )
                .overlay {

                    Circle()
                        .stroke(
                            .white.opacity(
                                0.55
                            ),
                            lineWidth:
                                max(
                                    1,
                                    layout.visualScale
                                )
                        )
                }

        } else {

            Text(
                object.type.symbol
            )
            .font(
                .system(
                    size:
                        objectSymbolSize
                        * layout.visualScale
                )
            )
            .frame(
                width:
                    objectFrameSize
                    * layout.visualScale,
                height:
                    objectFrameSize
                    * layout.visualScale
            )
            .background(
                object.type.isObstacle
                ? Color.red.opacity(0.72)
                : Color.green.opacity(0.72)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        objectCornerRadius
                        * layout.visualScale,
                    style:
                        .continuous
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        objectCornerRadius
                        * layout.visualScale,
                    style:
                        .continuous
                )
                .stroke(
                    .white.opacity(
                        0.42
                    ),
                    lineWidth:
                        max(
                            1,
                            layout.visualScale
                        )
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
    }


    // MARK: - AprilTags

    private func aprilTagsLayer(
        layout: MapCanvasLayout
    ) -> some View {

        ForEach(
            data.aprilTags
        ) { tag in

            aprilTagView(
                tag,
                layout:
                    layout
            )
            .position(
                layout.mapToScreen(
                    x:
                        tag.x,
                    z:
                        tag.z
                )
            )
        }
    }


    private func aprilTagView(
        _ tag: MapDisplayTag,
        layout: MapCanvasLayout
    ) -> some View {

        ZStack {

            Rectangle()
                .fill(
                    Color.black
                )


            Rectangle()
                .stroke(
                    tag.isReference
                    ? Color.red
                    : Color.white,
                    lineWidth:
                        max(
                            1,
                            2 * layout.visualScale
                        )
                )


            Text(
                "\(tag.id)"
            )
            .font(
                .system(
                    size:
                        tagFontSize
                        * layout.visualScale,
                    weight:
                        .bold
                )
            )
            .foregroundStyle(
                .white
            )
        }
        .frame(
            width:
                tagSize
                * layout.visualScale,
            height:
                tagSize
                * layout.visualScale
        )
        .rotationEffect(
            .radians(
                Double(
                    tag.rotation
                )
            )
        )
    }


    private func robotPoseView(
        _ pose: RobotPose,
        color: Color,
        label: String,
        layout: MapCanvasLayout,
        isRotationReversed:
            Bool = false
    ) -> some View {

        Rectangle()
            .fill(
                color
            )
            .frame(
                width:
                    robotSize
                    * layout.visualScale,
                height:
                    robotSize
                    * layout.visualScale
            )
            .overlay {

                Text(
                    label
                )
                .font(
                    .system(
                        size:
                            10
                            * layout.visualScale,
                        weight:
                            .bold
                    )
                )
                .foregroundStyle(
                    .white
                )
            }
            .rotationEffect(
                .radians(
                    Double(
                        isRotationReversed
                        ? -pose.rotation
                        : pose.rotation
                    )
                )
            )
    }


    // MARK: - Drawing Gesture

    private func drawingGesture(
        layout: MapCanvasLayout
    ) -> some Gesture {

        DragGesture(
            minimumDistance:
                0
        )
        .onChanged { value in

            let mapPoint =
                layout.screenToMap(
                    value.location
                )


            onAddRawPoint?(
                mapPoint
            )
        }
        .onEnded { _ in

            onFinishDrawing?()
        }
    }
}


// MARK: - Map Canvas Layout

struct MapCanvasLayout {

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

    let visualScale:
        CGFloat


    init(
        data: MapDisplayData,
        size: CGSize,
        mapPadding: CGFloat,
        minimumMapPadding: CGFloat,
        mapPaddingScale: CGFloat,
        mapWorldPadding: Float,
        minimumExtent: Float,
        singleTagForwardExtent: Float,
        meaningfulExtentThreshold: Float,
        allowsCourseDrawing: Bool,
        minimumForwardDrawingDistance: Float,
        drawingBackMargin: Float,
        designCanvasSize: CGFloat
    ) {

        let bounds =
            MapCanvasLayout.calculateBounds(
                data:
                    data,
                mapWorldPadding:
                    mapWorldPadding,
                minimumExtent:
                    minimumExtent,
                singleTagForwardExtent:
                    singleTagForwardExtent,
                meaningfulExtentThreshold:
                    meaningfulExtentThreshold,
                allowsCourseDrawing:
                    allowsCourseDrawing,
                minimumForwardDrawingDistance:
                    minimumForwardDrawingDistance,
                drawingBackMargin:
                    drawingBackMargin
            )


        let effectivePadding =
            min(
                mapPadding,
                max(
                    minimumMapPadding,
                    min(
                        size.width,
                        size.height
                    )
                    * mapPaddingScale
                )
            )


        let usableWidth =
            max(
                size.width
                - effectivePadding * 2,
                1
            )

        let usableHeight =
            max(
                size.height
                - effectivePadding * 2,
                1
            )


        let scale =
            min(
                usableWidth
                    / CGFloat(
                        bounds.width
                    ),
                usableHeight
                    / CGFloat(
                        bounds.height
                    )
            )


        let contentWidth =
            CGFloat(
                bounds.width
            )
            * scale

        let contentHeight =
            CGFloat(
                bounds.height
            )
            * scale


        self.minX =
            bounds.minX

        self.minZ =
            bounds.minZ

        self.width =
            bounds.width

        self.height =
            bounds.height

        self.scale =
            scale

        offsetX =
            (
                size.width
                - contentWidth
            )
            / 2

        offsetY =
            (
                size.height
                - contentHeight
            )
            / 2

        visualScale =
            max(
                0.20,
                min(
                    size.width,
                    size.height
                )
                / designCanvasSize
            )
    }


    func mapToScreen(
        _ point: SIMD2<Float>
    ) -> CGPoint {

        mapToScreen(
            x:
                point.x,
            z:
                point.y
        )
    }


    func mapToScreen(
        x: Float,
        z: Float
    ) -> CGPoint {

        CGPoint(
            x:
                offsetX
                +
                CGFloat(
                    x
                    - minX
                )
                * scale,
            y:
                offsetY
                +
                CGFloat(
                    z
                    - minZ
                )
                * scale
        )
    }


    func screenToMap(
        _ point: CGPoint
    ) -> SIMD2<Float> {

        let x =
            minX
            +
            Float(
                (
                    point.x
                    - offsetX
                )
                / scale
            )


        let z =
            minZ
            +
            Float(
                (
                    point.y
                    - offsetY
                )
                / scale
            )


        return SIMD2<Float>(
            x,
            z
        )
    }


    // MARK: - Bounds

    private static func calculateBounds(
        data: MapDisplayData,
        mapWorldPadding: Float,
        minimumExtent: Float,
        singleTagForwardExtent: Float,
        meaningfulExtentThreshold: Float,
        allowsCourseDrawing: Bool,
        minimumForwardDrawingDistance: Float,
        drawingBackMargin: Float
    ) -> MapCanvasBounds {

        let persistentPoints =
            persistentGeometryPoints(
                from:
                    data
            )


        guard persistentPoints.isEmpty == false
        else {

            return paddedBounds(
                minX:
                    -minimumExtent / 2,
                maxX:
                    minimumExtent / 2,
                minZ:
                    -minimumExtent / 2,
                maxZ:
                    minimumExtent / 2,
                padding:
                    mapWorldPadding
            )
        }


        let tagPoints =
            data.aprilTags.map {
                SIMD2<Float>(
                    $0.x,
                    $0.z
                )
            }


        let realMinTagX =
            tagPoints
                .map { $0.x }
                .min()
            ?? 0

        let realMaxTagX =
            tagPoints
                .map { $0.x }
                .max()
            ?? 0

        let realMinTagZ =
            tagPoints
                .map { $0.y }
                .min()
            ?? 0

        let realMaxTagZ =
            tagPoints
                .map { $0.y }
                .max()
            ?? 0


        if allowsCourseDrawing {

            let realWidth =
                realMaxTagX
                - realMinTagX

            let width =
                max(
                    realWidth,
                    minimumExtent
                )

            let extraX =
                (
                    width
                    - realWidth
                )
                / 2

            let minX =
                realMinTagX
                - extraX
                - mapWorldPadding

            let maxX =
                realMaxTagX
                + extraX
                + mapWorldPadding

            let drawnMinZ =
                data.rawTrackPoints
                    .map { $0.y }
                    .min()
                ??
                data.trackPoints
                    .map { $0.y }
                    .min()
                ??
                0

            let upperZ =
                min(
                    -minimumForwardDrawingDistance,
                    drawnMinZ,
                    realMinTagZ
                )

            let lowerZ =
                max(
                    drawingBackMargin,
                    realMaxTagZ
                )

            return MapCanvasBounds(
                minX:
                    minX,
                maxX:
                    maxX,
                minZ:
                    upperZ,
                maxZ:
                    lowerZ
            )
        }


        let realMinX =
            persistentPoints
                .map { $0.x }
                .min()
            ?? 0

        let realMaxX =
            persistentPoints
                .map { $0.x }
                .max()
            ?? 0

        let realMinZ =
            persistentPoints
                .map { $0.y }
                .min()
            ?? 0

        let realMaxZ =
            persistentPoints
                .map { $0.y }
                .max()
            ?? 0


        let realWidth =
            realMaxX
            - realMinX

        let realHeight =
            realMaxZ
            - realMinZ

        let meaningfulExtent =
            max(
                realWidth,
                realHeight
            )


        if data.aprilTags.count == 1,
           meaningfulExtent < meaningfulExtentThreshold,
           let referenceTag =
            data.aprilTags.first {

            return paddedBounds(
                minX:
                    referenceTag.x
                    - minimumExtent / 2,
                maxX:
                    referenceTag.x
                    + minimumExtent / 2,
                minZ:
                    referenceTag.z
                    - singleTagForwardExtent,
                maxZ:
                    referenceTag.z
                    + minimumExtent / 2,
                padding:
                    mapWorldPadding
            )
        }


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


        return paddedBounds(
            minX:
                realMinX
                - extraX,
            maxX:
                realMaxX
                + extraX,
            minZ:
                realMinZ
                - extraZ,
            maxZ:
                realMaxZ
                + extraZ,
            padding:
                mapWorldPadding
        )
    }


    private static func persistentGeometryPoints(
        from data:
            MapDisplayData
    ) -> [SIMD2<Float>] {

        var points =
            data.aprilTags.map {
                SIMD2<Float>(
                    $0.x,
                    $0.z
                )
            }


        points.append(
            contentsOf:
                data.rawTrackPoints
        )

        points.append(
            contentsOf:
                data.trackPoints
        )

        points.append(
            contentsOf:
                data.mapObjects.map {
                    SIMD2<Float>(
                        $0.x,
                        $0.z
                    )
                }
        )


        return points
    }


    private static func paddedBounds(
        minX: Float,
        maxX: Float,
        minZ: Float,
        maxZ: Float,
        padding: Float
    ) -> MapCanvasBounds {

        MapCanvasBounds(
            minX:
                minX
                - padding,
            maxX:
                maxX
                + padding,
            minZ:
                minZ
                - padding,
            maxZ:
                maxZ
                + padding
        )
    }
}


// MARK: - Map Canvas Bounds

private struct MapCanvasBounds {

    let minX:
        Float

    let maxX:
        Float

    let minZ:
        Float

    let maxZ:
        Float


    var width:
        Float {

        maxX - minX
    }


    var height:
        Float {

        maxZ - minZ
    }
}
