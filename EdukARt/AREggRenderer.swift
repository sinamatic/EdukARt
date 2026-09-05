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
            .triggerRadius
            ?? 0.10 // ToDo: size


    private let eggCarryHeight:
        Float = -0.12 // ToDo: position


    private let eggCarryForwardOffset:
        Float = 0.07 // ToDo: position


    private let eggCupHeight:
        Float = -0.17 // ToDo: position


    private let eggCupBackwardOffset:
        Float = -0.07 // ToDo: position


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

        eggCups:
            [PlacedMapObject],

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

        var didRenderCarriedEgg =
            false


        for egg in eggs {

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

                guard didRenderCarriedEgg
                        == false
                else {

                    eggEntities[
                        egg.id
                    ]?.removeFromParent()

                    eggEntities[
                        egg.id
                    ] =
                        nil

                    previousStates[
                        egg.id
                    ] =
                        egg.state

                    continue
                }


                didRenderCarriedEgg =
                    true


                let entity =
                    ensureEggEntity(
                        id:
                            egg.id,

                        parent:
                            parent
                    )


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
                let eggCupID,
                let slot
            ):

                guard let eggCup
                    =
                    eggCups.first(
                        where: {
                            $0.id
                                == eggCupID
                        }
                    )
                else {
                    continue
                }

                let hadEntity =
                    eggEntities[
                        egg.id
                    ] != nil


                let entity =
                    ensureEggEntity(
                        id:
                            egg.id,

                        parent:
                            parent
                    )


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
                ] != egg.state
                    && hadEntity {

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
        slot _:
            Int,

        robotPose:
            RobotPose
    ) -> Transform {

        let robotRotation =
            simd_quatf(
                angle:
                    robotPose.rotation // ToDo: rotation
                    + EduardModelAlignment
                        .yawCorrection,

                axis:
                    SIMD3<Float>(
                        0,
                        1,
                        0
                    )
            )


        let backward =
            robotRotation.act(
                SIMD3<Float>(
                    0,
                    0,
                    1
                )
            )


        let position =
            robotPose.position
            + backward
            * EduardModelAlignment
                .backwardOffset
            - backward
            * eggCarryForwardOffset
            + SIMD3<Float>(
                0,
                eggCarryHeight,
                0
            )


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
        slot _:
            Int,

        eggCup:
            PlacedMapObject
    ) -> Transform {

        let eggCupRotation =
            simd_quatf(
                angle:
                    eggCup.rotation // ToDo: rotation
                    + .pi,

                axis:
                    SIMD3<Float>(
                        0,
                        1,
                        0
                    )
            )


        let backward =
            eggCupRotation.act(
                SIMD3<Float>(
                    0,
                    0,
                    1
                )
            )


        let position =
            SIMD3<Float>(
                eggCup.x, // ToDo: position
                eggCupHeight, // ToDo: position
                eggCup.z // ToDo: position
            )
            + backward
            * eggCupBackwardOffset



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
