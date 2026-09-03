//
//  AREggRenderer.swift
//  EdukARt-Rebuild
//
//  Renders collected eggs on Eduard and
//  permanently delivered eggs on Egg Cup.
//

import Foundation
import RealityKit
import simd
import UIKit


final class AREggRenderer {

    // ======================================================
    // MARK: - Tuning
    // ======================================================

    /// Name of Egg.usdz in the app bundle.
    private let eggModelName =
        "Egg"


    /// Desired approximate height of one egg.
    ///
    /// Adjust this value until Egg.usdz has
    /// the correct physical size.
    private let eggHeight:
        Float = MapObjectType
            .eggs
            .collisionRadius // ToDo: size


    // --------------------------------------------------
    // Eggs on Eduard
    // --------------------------------------------------
    //
    // These offsets are in ROBOT-LOCAL coordinates.
    //
    // X = left / right
    // Y = height
    // Z = forward / backward
    //
    // Adjust these values by trial and error.
    // --------------------------------------------------

    private let carriedEggOffsets:
        [SIMD3<Float>] = [

            SIMD3<Float>(
                -0.07, // ToDo: position
                0.31, // ToDo: position
                0.02 // ToDo: position
            ),

            SIMD3<Float>(
                0.07, // ToDo: position
                0.31, // ToDo: position
                0.02 // ToDo: position
            )
        ]


    // --------------------------------------------------
    // Eggs on Egg Cup
    // --------------------------------------------------
    //
    // These offsets are Egg-Cup-local.
    //
    // You can tune these later without touching
    // gameplay or collision logic.
    // --------------------------------------------------

    private let eggCupEggOffsets:
        [SIMD3<Float>] = [

            SIMD3<Float>(
                -0.07, // ToDo: position
                0.08, // ToDo: position
                0 // ToDo: position
            ),

            SIMD3<Float>(
                0.07, // ToDo: position
                0.08, // ToDo: position
                0 // ToDo: position
            ),

            SIMD3<Float>(
                0, // ToDo: position
                0.08, // ToDo: position
                0.08 // ToDo: position
            ),

            SIMD3<Float>(
                0, // ToDo: position
                0.08, // ToDo: position
                -0.08 // ToDo: position
            )
        ]


    /// Duration of robot -> Egg Cup movement.
    private let deliveryAnimationDuration:
        TimeInterval = 0.8


    // ======================================================
    // MARK: - State
    // ======================================================

    private var eggEntities:
        [UUID: Entity] = [:]


    private var previousStates:
        [UUID: RuntimeEgg.State] = [:]


    // ======================================================
    // MARK: - Update
    // ======================================================

    func update(
        eggs:
            [RuntimeEgg],

        robotPose:
            RobotPose?,

        eggCup:
            PlacedMapObject?,

        parent:
            Entity?
    ) {

        guard let parent
        else {
            return
        }


        let activeIDs =
            Set(
                eggs.map {
                    $0.id
                }
            )


        // --------------------------------------------------
        // Remove eggs that no longer exist
        // --------------------------------------------------

        for id in
            Array(
                eggEntities.keys
            )
        where activeIDs.contains(id)
            == false {

            eggEntities[id]?
                .removeFromParent()

            eggEntities[id] =
                nil

            previousStates[id] =
                nil
        }


        // --------------------------------------------------
        // Update/create eggs
        // --------------------------------------------------

        for egg in eggs {

            let entity =
                ensureEggEntity(
                    id:
                        egg.id,

                    parent:
                        parent
                )


            switch egg.state {


            // ==================================================
            // Carried
            // ==================================================

            case .carried(
                let slot
            ):

                guard let robotPose
                else {
                    continue
                }


                let transform =
                    carriedTransform(
                        slot:
                            slot,

                        robotPose:
                            robotPose
                    )


                entity.transform =
                    transform


            // ==================================================
            // Delivered
            // ==================================================

            case .delivered(
                let slot
            ):

                guard let eggCup
                else {
                    continue
                }


                let target =
                    eggCupTransform(
                        slot:
                            slot,

                        eggCup:
                            eggCup
                    )


                // Animate only when the state
                // actually changed to delivered.
                if previousStates[
                    egg.id
                ] != egg.state {

                    entity.move(
                        to:
                            target,

                        relativeTo:
                            parent,

                        duration:
                            deliveryAnimationDuration,

                        timingFunction:
                            .easeInOut
                    )

                } else {

                    entity.transform =
                        target
                }
            }


            previousStates[
                egg.id
            ] =
                egg.state
        }
    }


    // ======================================================
    // MARK: - Create Entity
    // ======================================================

    private func ensureEggEntity(
        id:
            UUID,

        parent:
            Entity
    ) -> Entity {

        if let entity =
            eggEntities[
                id
            ] {

            return entity
        }


        let root =
            Entity()

        root.name =
            "RuntimeEgg-\(id)"


        do {

            let model =
                try Entity.load(
                    named:
                        eggModelName
                )


            normalizeEggSize(
                model
            )


            correctEggPivot(
                model
            )


            root.addChild(
                model
            )

        } catch {

            print(
                "# EGG MODEL ERROR |",
                error
            )


            // Simple fallback.
            let fallback =
                ModelEntity(
                    mesh:
                        .generateSphere(
                            radius:
                                0.04 // ToDo: size
                        ),

                    materials: [
                        SimpleMaterial(
                            color:
                                .white,

                            isMetallic:
                                false
                        )
                    ]
                )


            root.addChild(
                fallback
            )
        }


        parent.addChild(
            root
        )


        eggEntities[
            id
        ] =
            root


        return root
    }


    // ======================================================
    // MARK: - Carried Transform
    // ======================================================

    private func carriedTransform(
        slot:
            Int,

        robotPose:
            RobotPose
    ) -> Transform {

        let safeSlot =
            min(
                slot,
                carriedEggOffsets.count - 1
            )


        let localOffset =
            carriedEggOffsets[
                safeSlot
            ]


        let robotRotation =
            simd_quatf(
                angle:
                    robotPose.rotation, // ToDo: rotation

                axis:
                    SIMD3<Float>(
                        0,
                        1,
                        0
                    )
            )


        let rotatedOffset =
            robotRotation.act(
                localOffset
            )


        let position =
            robotPose.position
            + rotatedOffset


        return Transform(
            scale:
                .one,

            rotation:
                robotRotation,

            translation:
                position
        )
    }


    // ======================================================
    // MARK: - Egg Cup Transform
    // ======================================================

    private func eggCupTransform(
        slot:
            Int,

        eggCup:
            PlacedMapObject
    ) -> Transform {

        let safeSlot =
            min(
                slot,
                eggCupEggOffsets.count - 1
            )


        let eggCupRotation =
            simd_quatf(
                angle:
                    eggCup.rotation, // ToDo: rotation

                axis:
                    SIMD3<Float>(
                        0,
                        1,
                        0
                    )
            )


        let localOffset =
            eggCupEggOffsets[
                safeSlot
            ]


        let rotatedOffset =
            eggCupRotation.act(
                localOffset
            )


        let position =
            SIMD3<Float>(
                eggCup.x, // ToDo: position
                0, // ToDo: position
                eggCup.z // ToDo: position
            )
            + rotatedOffset


        return Transform(
            scale:
                .one,

            rotation:
                eggCupRotation,

            translation:
                position
        )
    }


    // ======================================================
    // MARK: - Model Size
    // ======================================================

    private func normalizeEggSize(
        _ entity:
            Entity
    ) {

        let bounds =
            entity.visualBounds(
                relativeTo:
                    nil
            )


        let height =
            bounds.extents.y


        guard height > 0.0001
        else {
            return
        }


        let scale =
            eggHeight
            / height


        entity.scale *=
            SIMD3<Float>(
                repeating:
                    scale // ToDo: size
            )
    }


    // ======================================================
    // MARK: - Pivot
    // ======================================================

    private func correctEggPivot(
        _ entity:
            Entity
    ) {

        let bounds =
            entity.visualBounds(
                relativeTo:
                    entity
            )


        entity.position.y -=
            bounds.min.y // ToDo: position
    }


    // ======================================================
    // MARK: - Clear
    // ======================================================

    func clear() {

        for entity in
            eggEntities.values {

            entity.removeFromParent()
        }


        eggEntities
            .removeAll()


        previousStates
            .removeAll()
    }
}
