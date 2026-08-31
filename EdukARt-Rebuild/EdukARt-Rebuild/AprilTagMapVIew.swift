//
//  AprilTagMapView.swift
//  EdukARt-Rebuild
//

import SwiftUI


// MARK: - AprilTag Map View

struct AprilTagMapView: View {

    @ObservedObject var mapBuilder: AprilTagMapBuilder
    @ObservedObject var course: Course

    let mapWidthFactor: CGFloat
    let mapAlignment: Alignment
    let showsClearCourseButton: Bool
    let allowsCourseDrawing: Bool
    let backgroundColor: Color
    let borderColor: Color
    let borderLineWidth: CGFloat

    init(
        mapBuilder: AprilTagMapBuilder,
        course: Course,
        mapWidthFactor: CGFloat = 1.0 / 3.0,
        mapAlignment: Alignment = .topTrailing,
        showsClearCourseButton: Bool = true,
        allowsCourseDrawing: Bool = false,
        backgroundColor: Color = Color.black.opacity(0.52),
        borderColor: Color = Color.white.opacity(0.7),
        borderLineWidth: CGFloat = 1
    ) {
        self.mapBuilder = mapBuilder
        self.course = course
        self.mapWidthFactor = mapWidthFactor
        self.mapAlignment = mapAlignment
        self.showsClearCourseButton = showsClearCourseButton
        self.allowsCourseDrawing = allowsCourseDrawing
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderLineWidth = borderLineWidth
    }


    // MARK: - Settings

    // Inner spacing between the map border
    // and the AprilTag positions.
    private let mapPadding:
        CGFloat = 28

    // Minimum displayed map extent in metres.
    //
    // This prevents an almost straight line of tags
    // from becoming only a few pixels wide.
    private let minimumExtent:
        Float = 1.0

    // AprilTag symbol size.
    private let tagSize:
        CGFloat = 24

    private let referenceDotSize:
        CGFloat = 7

    private let tagFontSize:
        CGFloat = 10

    private let cornerRadius:
        CGFloat = 18


    // MARK: - Body

    var body: some View {

        GeometryReader { geometry in

            let maximumMapSize =
                min(
                    geometry.size.width,
                    geometry.size.height
                )

            let mapSize =
                min(
                    geometry.size.width * mapWidthFactor,
                    maximumMapSize
                )

            ZStack(alignment: .topTrailing) {

                ZStack {

                    // Map background
                    backgroundColor


                    if mapBuilder.mapPoints.isEmpty {

                        Text(
                            "No AprilTags mapped yet"
                        )
                        .foregroundStyle(
                            .white
                        )
                        .font(
                            .caption
                        )

                    } else {

                        mapContent(
                            size: mapSize
                        )
                    }
                }
                .frame(
                    width: mapSize,
                    height: mapSize
                )
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
                        lineWidth: borderLineWidth
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: mapAlignment
                )

                if showsClearCourseButton {
                    Button(
                        "Clear Course"
                    ) {

                        course.reset()
                    }
                }
            }
        }
    }


    // MARK: - Map Content

    private func mapContent(
        size: CGFloat
    ) -> some View {

        let bounds =
            calculateMapBounds()


        let usableSize =
            max(
                size
                - mapPadding * 2,
                1
            )


        // --------------------------------------------------
        // Uniform map scale
        // --------------------------------------------------
        //
        // X and Z always use the same scale.
        //
        // This means:
        //
        // 1 metre in X
        // =
        // 1 metre in Z
        //
        // The room therefore keeps its real proportions.
        // --------------------------------------------------

        let scale =
            min(
                usableSize
                    / CGFloat(
                        bounds.width
                    ),

                usableSize
                    / CGFloat(
                        bounds.height
                    )
            )


        // --------------------------------------------------
        // Center map content inside the square
        // --------------------------------------------------
        //
        // Example:
        //
        // A 1 x 7 m map only uses a narrow section
        // of the square.
        //
        // The remaining space is distributed equally.
        // --------------------------------------------------

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


        let horizontalOffset =
            (
                size
                - contentWidth
            )
            / 2

        let verticalOffset =
            (
                size
                - contentHeight
            )
            / 2


        return ZStack {
            backgroundColor.opacity(0.001)

            // --------------------------------------------------
            // Draw Course
            // --------------------------------------------------

            coursePath(
                bounds:
                    bounds,

                scale:
                    scale,

                horizontalOffset:
                    horizontalOffset,

                verticalOffset:
                    verticalOffset
            )


            // --------------------------------------------------
            // Draw AprilTags
            // --------------------------------------------------

            ForEach(
                mapBuilder.mapPoints
            ) { point in

                aprilTagView(
                    point
                )
                .position(

                    // X axis:
                    // smaller X = further left
                    // larger X = further right
                    x:
                        horizontalOffset
                        +
                        CGFloat(
                            point.x
                            - bounds.minX
                        )
                        * scale,

                    // Z axis:
                    // current orientation of the map
                    y:
                        verticalOffset
                        +
                        CGFloat(
                            point.z
                            - bounds.minZ
                        )
                        * scale
                )
            }
        }
        .frame(
            width: size,
            height: size
        )
        .contentShape(Rectangle())
        .highPriorityGesture(
            courseDrawingGesture(
                bounds: bounds,
                scale: scale,
                horizontalOffset: horizontalOffset,
                verticalOffset: verticalOffset
            )
        )
    }
    
    // MARK: - Course Path

    private func coursePath(
        bounds: MapBounds,
        scale: CGFloat,
        horizontalOffset: CGFloat,
        verticalOffset: CGFloat
    ) -> some View {

        ZStack {
            let points =
                course.rawPoints.map { point in
                    CGPoint(
                        x:
                            horizontalOffset
                            +
                            CGFloat(point.x - bounds.minX)
                            * scale,

                        y:
                            verticalOffset
                            +
                            CGFloat(point.y - bounds.minZ)
                            * scale
                    )
                }

            ForEach(Array(zip(points.indices, zip(points, points.dropFirst()))), id: \.0) { index, segment in
                Path { path in
                    path.move(to: segment.0)
                    path.addLine(to: segment.1)
                }
                .stroke(
                    courseColor(at: CGFloat(index) / CGFloat(max(points.count - 2, 1))),
                    style:
                        StrokeStyle(
                            lineWidth:
                                4,

                            lineCap:
                                .round,

                            lineJoin:
                                .round
                        )
                )
            }

            if let startPoint = points.first {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 10, height: 10)
                    .position(startPoint)
            }

            if points.count > 1, let endPoint = points.last {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .position(endPoint)
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
                0.85 + progress * 0.15,

            blue:
                0
        )
    }
    
    // MARK: - Course Drawing Gesture

    private func courseDrawingGesture(
        bounds: MapBounds,
        scale: CGFloat,
        horizontalOffset: CGFloat,
        verticalOffset: CGFloat
    ) -> some Gesture {

        DragGesture(
            minimumDistance:
                0
        )
        .onChanged { value in

            guard allowsCourseDrawing else {
                return
            }

            // --------------------------------------------------
            // Screen -> Map
            // --------------------------------------------------

            let mapX =
                bounds.minX
                +
                Float(
                    (
                        value.location.x
                        - horizontalOffset
                    )
                    / scale
                )


            let mapZ =
                bounds.minZ
                +
                Float(
                    (
                        value.location.y
                        - verticalOffset
                    )
                    / scale
                )


            course.addRawPoint(
                x:
                    mapX,

                z:
                    mapZ
            )
        }
    }
    
    


    // MARK: - AprilTag Symbol

    private func aprilTagView(
        _ point: AprilTagMapPoint
    ) -> some View {

        ZStack {

            // Black AprilTag symbol
            Rectangle()
                .fill(
                    Color.black
                )


            // Tag border
            Rectangle()
                .stroke(
                    point.isReference
                    ? Color.red.opacity(0.85)
                    : Color.white,
                    lineWidth: 2
                )


            Text(
                "\(point.id)"
            )
            .foregroundStyle(
                .white
            )
            .font(
                .system(
                    size:
                        tagFontSize,

                    weight:
                        .bold
                )
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
                    -point.rotation
                )
            )
        )
    }


    // MARK: - Map Bounds

    private func calculateMapBounds()
        -> MapBounds {

        let points =
            mapBuilder.mapPoints


        let minX =
            points
                .map {
                    $0.x
                }
                .min()
            ?? 0

        let maxX =
            points
                .map {
                    $0.x
                }
                .max()
            ?? 0

        let minZ =
            points
                .map {
                    $0.z
                }
                .min()
            ?? 0

        let maxZ =
            points
                .map {
                    $0.z
                }
                .max()
            ?? 0


        // --------------------------------------------------
        // Actual mapped size
        // --------------------------------------------------

        let realWidth =
            maxX - minX

        let realHeight =
            maxZ - minZ


        // --------------------------------------------------
        // Minimum visible map size
        // --------------------------------------------------
        //
        // The coordinates themselves are not changed.
        //
        // Only additional empty map space is added
        // if the detected tags form a very thin line.
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


        // Distribute additional empty space equally.
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


        return MapBounds(

            minX:
                minX
                - extraX,

            maxX:
                maxX
                + extraX,

            minZ:
                minZ
                - extraZ,

            maxZ:
                maxZ
                + extraZ
        )
    }
}


// MARK: - Map Bounds

private struct MapBounds {

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
