//
//  AprilTagMapView.swift
//  EdukARt-Rebuild
//
//  Live AprilTag-map adapter for the shared 2D map renderer.
//

import SwiftUI
import simd


// MARK: - AprilTag Map View

struct AprilTagMapView: View {

    @ObservedObject var mapBuilder:
        AprilTagMapBuilder

    @ObservedObject var course:
        Course

    let mapWidthFactor:
        CGFloat

    let mapAlignment:
        Alignment

    let showsClearCourseButton:
        Bool

    let allowsCourseDrawing:
        Bool

    let backgroundColor:
        Color

    let borderColor:
        Color

    let borderLineWidth:
        CGFloat


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

        self.mapBuilder =
            mapBuilder

        self.course =
            course

        self.mapWidthFactor =
            mapWidthFactor

        self.mapAlignment =
            mapAlignment

        self.showsClearCourseButton =
            showsClearCourseButton

        self.allowsCourseDrawing =
            allowsCourseDrawing

        self.backgroundColor =
            backgroundColor

        self.borderColor =
            borderColor

        self.borderLineWidth =
            borderLineWidth
    }


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


            ZStack(
                alignment:
                    .topTrailing
            ) {

                MapCanvasView(
                    data:
                        displayData,

                    allowsCourseDrawing:
                        allowsCourseDrawing,

                    backgroundColor:
                        backgroundColor,

                    borderColor:
                        borderColor,

                    borderLineWidth:
                        borderLineWidth,

                    emptyText:
                        "No AprilTags mapped yet",

                    onAddRawPoint:
                        addRawPoint,

                    onFinishDrawing:
                        finishDrawing
                )
                .frame(
                    width:
                        mapSize,
                    height:
                        mapSize
                )
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity,
                    alignment:
                        mapAlignment
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


    // MARK: - Display Data

    private var displayData:
        MapDisplayData {

        MapDisplayData(
            aprilTags:
                mapBuilder.mapPoints.map { point in

                    MapDisplayTag(
                        id:
                            point.id,
                        x:
                            point.x,
                        z:
                            point.z,
                        rotation:
                            point.rotation,
                        isReference:
                            point.isReference
                    )
                },

            referenceTagID:
                mapBuilder.referenceTagID,

            rawTrackPoints:
                course.rawPoints
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
}
