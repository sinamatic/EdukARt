//
//  ARTrackRenderer.swift
//  EdukARt-Rebuild
//
//  Renders the stored 2D track centerline
//  as dashed RealityKit geometry.
//

import RealityKit
import simd
import UIKit


final class ARTrackRenderer {

    // MARK: - Settings

    private let lineWidth:
        Float = 0.035

    private let lineHeight:
        Float = 0.004

    private let dashLength:
        Float = 0.30

    private let gapLength:
        Float = 0.10

    private let floorOffset:
        Float = 0.006


    // MARK: - Render Track

    func render(
        trackPoints: [StoredTrackPoint],
        parent: Entity
    ) {

        guard trackPoints.count >= 2
        else {
            return
        }


        // Remove previously rendered track.
        parent.findEntity(
            named:
                "ARTrack"
        )?
        .removeFromParent()


        let trackRoot =
            Entity()

        trackRoot.name =
            "ARTrack"

        parent.addChild(
            trackRoot
        )


        let step =
            dashLength
            + gapLength

        var patternPosition:
            Float = 0


        for index in 0..<(trackPoints.count - 1) {

            let start =
                SIMD3<Float>(
                    trackPoints[index].x,
                    floorOffset,
                    trackPoints[index].z
                )

            let end =
                SIMD3<Float>(
                    trackPoints[index + 1].x,
                    floorOffset,
                    trackPoints[index + 1].z
                )


            patternPosition =
                addDashedSegment(
                from:
                    start,

                to:
                    end,

                parent:
                    trackRoot,

                patternPosition:
                    patternPosition,

                step:
                    step
            )
        }
    }


    // MARK: - Dashed Segment

    private func addDashedSegment(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        parent: Entity,
        patternPosition initialPatternPosition: Float,
        step: Float
    ) -> Float {

        let vector =
            end - start

        let distance =
            simd_length(
                vector
            )


        guard distance > 0.001
        else {
            return initialPatternPosition
        }


        let direction =
            simd_normalize(
                vector
            )


        var travelled:
            Float = 0

        var patternPosition =
            initialPatternPosition


        while travelled < distance {

            let remaining =
                distance
                - travelled

            let isDash =
                patternPosition < dashLength

            let remainingInPattern =
                isDash
                ? dashLength - patternPosition
                : step - patternPosition

            let currentLength =
                min(
                    remaining,
                    remainingInPattern
                )


            if isDash {

                let dashStart =
                    start
                    + direction
                    * travelled


                let dashEnd =
                    dashStart
                    + direction
                    * currentLength


                addDash(
                    from:
                        dashStart,

                    to:
                        dashEnd,

                    parent:
                        parent
                )
            }


            travelled +=
                currentLength

            patternPosition +=
                currentLength

            if patternPosition >= step {
                patternPosition =
                    patternPosition
                    .truncatingRemainder(
                        dividingBy:
                            step
                    )
            }
        }


        return patternPosition
    }


    // MARK: - Dash

    private func addDash(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        parent: Entity
    ) {

        let vector =
            end - start

        let length =
            simd_length(
                vector
            )


        guard length > 0.001
        else {
            return
        }


        let center =
            (
                start
                + end
            )
            / 2


        let mesh =
            MeshResource.generateBox(
                size:
                    SIMD3<Float>(
                        lineWidth,
                        lineHeight,
                        length
                    )
            )


        let material =
            SimpleMaterial(
                color:
                    .white,
                isMetallic:
                    false
            )


        let entity =
            ModelEntity(
                mesh:
                    mesh,
                materials:
                    [
                        material
                    ]
            )


        entity.position =
            center


        // Box is generated along local Z.
        // Rotate local Z toward the segment direction.
        let direction =
            simd_normalize(
                vector
            )


        entity.orientation =
            simd_quatf(
                from:
                    SIMD3<Float>(
                        0,
                        0,
                        1
                    ),

                to:
                    direction
            )


        parent.addChild(
            entity
        )
    }
}
