//
//  Course.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 26.08.26.
//

import Foundation
import simd
import Combine


// MARK: - Course

final class Course:
    ObservableObject {

    // Raw points recorded from finger input.
    //
    // X and Y of SIMD2 represent:
    //
    // x = map X
    // y = map Z
    //
    // Values are stored in metres.
    @Published private(set)
    var rawPoints:
        [SIMD2<Float>] = []


    // MARK: - Add Point
    
    func addPoint(
        x: Float,
        z: Float
    ) {

        let newPoint =
            SIMD2<Float>(
                x,
                z
            )


        // --------------------------------------------------
        // First point
        // --------------------------------------------------

        guard let lastPoint =
            rawPoints.last

        else {

            rawPoints.append(
                newPoint
            )

            return
        }


        // --------------------------------------------------
        // Minimum distance
        // --------------------------------------------------
        //
        // Do not store hundreds of nearly identical
        // points while the finger moves slowly.
        // --------------------------------------------------

        let minimumPointDistance:
            Float = 0.03


        let distance =
            simd_distance(
                lastPoint,
                newPoint
            )


        guard distance
                >= minimumPointDistance

        else {
            return
        }


        rawPoints.append(
            newPoint
        )
    }


    // MARK: - Reset

    func reset() {

        rawPoints.removeAll()
    }
}


