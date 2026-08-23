//
//  AprilTagMapView.swift
//  EdukARt-Rebuild
//

import SwiftUI


// MARK: - AprilTag Map View

struct AprilTagMapView: View {

    @ObservedObject var mapBuilder:
        AprilTagMapBuilder


    // MARK: - Settings

    // Size of the square map relative to the screen width.
    //
    // 1 / 3 = one third of the available screen width.
    private let mapWidthFactor:
        CGFloat = 1.0 / 3.0

    // Inner spacing between the map border
    // and the AprilTag positions.
    private let mapPadding:
        CGFloat = 10

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

            let mapSize =
                geometry.size.width
                * mapWidthFactor


            ZStack {

                // Map background
                Color.black
                    .opacity(0.65)


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
                    Color.white
                        .opacity(0.7),
                    lineWidth: 1
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topTrailing
            )
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


            // White border
            Rectangle()
                .stroke(
                    Color.white,
                    lineWidth: 2
                )


            // Reference tag
            if point.isReference {

                Circle()
                    .fill(
                        Color.white
                    )
                    .frame(
                        width:
                            referenceDotSize,

                        height:
                            referenceDotSize
                    )

            } else {

                // Other map tags
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
