//
//  Course.swift
//  EdukARt-Rebuild
//
//  Stores and processes the user-drawn track centerline.
//
//  The finger input is first stored as raw points in
//  physical map coordinates. It is then simplified,
//  smoothed and resampled at a constant physical distance.
//

import Foundation
import simd
import Combine


// MARK: - Course

final class Course: ObservableObject {

    // ======================================================
    // MARK: - Settings
    // ======================================================

    // Ignore extremely small finger movements.
    private let minimumInputDistance:
        Float = 0.01

    // Ramer-Douglas-Peucker simplification tolerance.
    private let simplificationTolerance:
        Float = 0.03

    // Number of smoothing passes.
    private let smoothingIterations:
        Int = 2

    // Final distance between track points in metres.
    //
    // 0.10 = one point every 10 cm.
    private let resamplingDistance:
        Float = 0.10


    // ======================================================
    // MARK: - Points
    // ======================================================

    // Direct finger input converted into map coordinates.
    @Published private(set)
    var rawPoints:
        [SIMD2<Float>] = []

    // Final normalized centerline.
    //
    // This is the representation that is saved and later
    // used for AR rendering.
    @Published private(set)
    var trackPoints:
        [SIMD2<Float>] = []


    // ======================================================
    // MARK: - Drawing
    // ======================================================

    func beginDrawing() {

        rawPoints.removeAll()
        trackPoints.removeAll()
    }


    func addRawPoint(
        x: Float,
        z: Float
    ) {

        let newPoint =
            SIMD2<Float>(
                x,
                z
            )


        // Always accept the first point.
        guard let lastPoint =
            rawPoints.last
        else {

            rawPoints.append(
                newPoint
            )

            return
        }


        // Avoid hundreds of almost identical samples.
        let distance =
            simd_distance(
                lastPoint,
                newPoint
            )


        guard distance
                >= minimumInputDistance
        else {
            return
        }


        rawPoints.append(
            newPoint
        )
    }


    // MARK: - Finish Drawing

    func finishDrawing() {

        guard rawPoints.count >= 2
        else {

            trackPoints.removeAll()

            return
        }


        // --------------------------------------------------
        // 1. Raw finger points
        // --------------------------------------------------

        let raw =
            rawPoints


        // --------------------------------------------------
        // 2. Simplify
        // --------------------------------------------------

        let simplified =
            simplify(
                points:
                    raw,

                tolerance:
                    simplificationTolerance
            )


        // --------------------------------------------------
        // 3. Smooth
        // --------------------------------------------------

        var smoothed =
            simplified


        for _ in 0..<smoothingIterations {

            smoothed =
                smooth(
                    points:
                        smoothed
                )
        }


        // --------------------------------------------------
        // 4. Resample by physical distance
        // --------------------------------------------------

        trackPoints =
            resample(
                points:
                    smoothed,

                spacing:
                    resamplingDistance
            )

        // Raw finger input is no longer required
        // after the final track has been created.
        rawPoints.removeAll()
        
    }


    // ======================================================
    // MARK: - Simplification
    // ======================================================

    private func simplify(
        points: [SIMD2<Float>],
        tolerance: Float
    ) -> [SIMD2<Float>] {

        guard points.count > 2
        else {
            return points
        }


        let first =
            points[0]

        let last =
            points[
                points.count - 1
            ]


        var maximumDistance:
            Float = 0

        var splitIndex:
            Int = 0


        for index in 1..<(points.count - 1) {

            let distance =
                perpendicularDistance(
                    point:
                        points[index],

                    lineStart:
                        first,

                    lineEnd:
                        last
                )


            if distance > maximumDistance {

                maximumDistance =
                    distance

                splitIndex =
                    index
            }
        }


        if maximumDistance > tolerance {

            let firstPart =
                simplify(
                    points:
                        Array(
                            points[
                                0...splitIndex
                            ]
                        ),

                    tolerance:
                        tolerance
                )


            let secondPart =
                simplify(
                    points:
                        Array(
                            points[
                                splitIndex...
                            ]
                        ),

                    tolerance:
                        tolerance
                )


            return
                Array(
                    firstPart.dropLast()
                )
                +
                secondPart
        }


        return [
            first,
            last
        ]
    }


    private func perpendicularDistance(
        point: SIMD2<Float>,
        lineStart: SIMD2<Float>,
        lineEnd: SIMD2<Float>
    ) -> Float {

        let line =
            lineEnd
            - lineStart


        let lineLengthSquared =
            simd_length_squared(
                line
            )


        guard lineLengthSquared > 0
        else {

            return simd_distance(
                point,
                lineStart
            )
        }


        let t =
            max(
                0,
                min(
                    1,
                    simd_dot(
                        point - lineStart,
                        line
                    )
                    / lineLengthSquared
                )
            )


        let projection =
            lineStart
            + line * t


        return simd_distance(
            point,
            projection
        )
    }


    // ======================================================
    // MARK: - Smoothing
    // ======================================================

    private func smooth(
        points: [SIMD2<Float>]
    ) -> [SIMD2<Float>] {

        guard points.count >= 2
        else {
            return points
        }


        var result:
            [SIMD2<Float>] = []


        // Keep exact start point.
        result.append(
            points[0]
        )


        for index in 0..<(points.count - 1) {

            let pointA =
                points[index]

            let pointB =
                points[index + 1]


            // Chaikin smoothing.
            let q =
                pointA * 0.75
                + pointB * 0.25

            let r =
                pointA * 0.25
                + pointB * 0.75


            result.append(
                q
            )

            result.append(
                r
            )
        }


        // Keep exact end point.
        result.append(
            points[
                points.count - 1
            ]
        )


        return result
    }


    // ======================================================
    // MARK: - Resampling
    // ======================================================

    private func resample(
        points: [SIMD2<Float>],
        spacing: Float
    ) -> [SIMD2<Float>] {

        guard points.count >= 2,
              spacing > 0
        else {
            return points
        }


        var result:
            [SIMD2<Float>] = [
                points[0]
            ]


        var previous =
            points[0]

        var distanceSinceLastSample:
            Float = 0


        for index in 1..<points.count {

            var segmentStart =
                previous

            let segmentEnd =
                points[index]


            var segmentVector =
                segmentEnd
                - segmentStart

            var segmentLength =
                simd_length(
                    segmentVector
                )


            while distanceSinceLastSample
                    + segmentLength
                    >= spacing {

                let missingDistance =
                    spacing
                    - distanceSinceLastSample


                let direction =
                    simd_normalize(
                        segmentVector
                    )


                let newPoint =
                    segmentStart
                    + direction
                    * missingDistance


                result.append(
                    newPoint
                )


                segmentStart =
                    newPoint

                segmentVector =
                    segmentEnd
                    - segmentStart

                segmentLength =
                    simd_length(
                        segmentVector
                    )

                distanceSinceLastSample =
                    0
            }


            distanceSinceLastSample +=
                segmentLength

            previous =
                segmentEnd
        }


        // Always retain the exact end point.
        if let last =
            points.last,

           let lastResult =
            result.last,

           simd_distance(
                last,
                lastResult
           ) > 0.001 {

            result.append(
                last
            )
        }


        return result
    }


    // ======================================================
    // MARK: - Persistence
    // ======================================================

    func storedTrackPoints()
        -> [StoredTrackPoint] {

        trackPoints.map { point in

            StoredTrackPoint(
                x:
                    point.x,

                z:
                    point.y
            )
        }
    }


    func load(
        storedTrackPoints: [StoredTrackPoint]
    ) {

        rawPoints.removeAll()

        trackPoints =
            storedTrackPoints.map { point in

                SIMD2<Float>(
                    point.x,
                    point.z
                )
            }
    }


    // ======================================================
    // MARK: - Reset
    // ======================================================

    func reset() {

        rawPoints.removeAll()
        trackPoints.removeAll()
    }
}
