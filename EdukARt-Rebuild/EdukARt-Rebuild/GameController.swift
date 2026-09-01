//
//  GameController.swift
//  EdukARt-Rebuild
//
//  Created for the EdukARt gameplay system.
//
//  GameController manages the runtime state of one game session.
//  It receives the current robot pose, checks collisions with
//  placed map objects and interprets these collisions as
//  gameplay events.
//
//  The persistent GameMap is never modified during gameplay.
//  Instead, activeMapObjects contains a temporary copy of the
//  objects for the current game session.
//

import Foundation
import simd
import Combine


// MARK: - Shit Dot

struct ShitDot:
    Identifiable {

    let id =
        UUID()

    let position:
        SIMD2<Float>

    let radius:
        Float
}


@MainActor
final class GameController:
    ObservableObject {

    // ======================================================
    // MARK: - Published Game State
    // ======================================================

    /// Current score of the running game.
    @Published private(set)
    var score:
        Int = 0


    /// Number of collected eggs.
    @Published private(set)
    var collectedEggs:
        Int = 0


    /// Temporary objects of the current game session.
    ///
    /// For example, collected eggs are removed from this array,
    /// while the original GameMap remains unchanged.
    @Published private(set)
    var activeMapObjects:
        [PlacedMapObject]


    /// Indicates whether Eduard currently leaves a shit trail.
    @Published private(set)
    var isLeavingShitTrail:
        Bool = false


    /// Current gameplay status.
    ///
    /// Useful for debugging and later for UI messages.
    @Published private(set)
    var statusText:
        String = ""


    // ======================================================
    // MARK: - Shit Effect
    // ======================================================

    @Published private(set)
    var shitDots:
        [ShitDot] = []


    private var shitEffectTask:
        Task<Void, Never>?

    private var currentRobotPose:
        RobotPose = .zero


    // ======================================================
    // MARK: - Collision
    // ======================================================

    private let collisionManager =
        CollisionManager()


    // ======================================================
    // MARK: - Init
    // ======================================================

    init(
        map: GameMap
    ) {

        // Runtime copy.
        //
        // The stored map itself is not modified.
        self.activeMapObjects =
            map.mapObjects
    }


    // ======================================================
    // MARK: - Robot Pose Update
    // ======================================================

    /// Updates the gameplay system with the current robot pose.
    ///
    /// This function can receive either:
    ///
    /// - the physical Eduard pose from AprilTag #0, or
    /// - the logical pose of EduardSimulation.
    ///
    /// CollisionManager therefore does not need to know
    /// which robot representation is currently active.
    func updateRobotPose(
        _ pose:
            RobotPose
    ) {

        currentRobotPose =
            pose

        let collisions =
            collisionManager.update(
                robotPose:
                    pose,

                objects:
                    activeMapObjects
            )


        // --------------------------------------------------
        // Handle collision events
        // --------------------------------------------------

        for collision in collisions {

            handleCollision(
                collision
            )
        }
    }


    // ======================================================
    // MARK: - Collision Handling
    // ======================================================

    private func handleCollision(
        _ collision:
            MapObjectCollision
    ) {

        switch collision.phase {


        // --------------------------------------------------
        // Collision started
        // --------------------------------------------------

        case .began:

            print(
                "# COLLISION BEGAN | \(collision.object.type.name)"
            )


            handleCollisionBegan(
                with:
                    collision.object
            )


        // --------------------------------------------------
        // Collision ended
        // --------------------------------------------------

        case .ended:

            print(
                "# COLLISION ENDED | \(collision.object.type.name)"
            )


            handleCollisionEnded(
                with:
                    collision.object
            )
        }
    }


    // ======================================================
    // MARK: - Collision Began
    // ======================================================

    private func handleCollisionBegan(
        with object:
            PlacedMapObject
    ) {

        switch object.type {


        // --------------------------------------------------
        // Eggs
        // --------------------------------------------------

        case .eggs:

            collectEggs(
                object
            )


        // --------------------------------------------------
        // Shit
        // --------------------------------------------------

        case .shit:

            hitShit(
                object
            )


        // --------------------------------------------------
        // Oil
        // --------------------------------------------------

        case .oil:

            hitOil()


        // --------------------------------------------------
        // Water
        // --------------------------------------------------

        case .water:

            hitWater()


        // --------------------------------------------------
        // Rock
        // --------------------------------------------------

        case .rock:

            hitRock()


        // --------------------------------------------------
        // Tree
        // --------------------------------------------------

        case .tree:

            hitTree()


        // --------------------------------------------------
        // Tongue
        // --------------------------------------------------

        case .tongue:

            hitTongue()
        }
    }


    // ======================================================
    // MARK: - Collision Ended
    // ======================================================

    private func handleCollisionEnded(
        with object:
            PlacedMapObject
    ) {

        // No action required yet.
    }


    // ======================================================
    // MARK: - Eggs
    // ======================================================

    private func collectEggs(
        _ object:
            PlacedMapObject
    ) {

        collectedEggs += 1

        score += 10

        statusText =
            "Egg collected"


        // Remove only from the current runtime session.
        activeMapObjects.removeAll {
            $0.id == object.id
        }


        print(
            "# GAME | Egg collected"
        )

        print(
            "# GAME | Eggs: \(collectedEggs)"
        )

        print(
            "# GAME | Score: \(score)"
        )
    }


    // ======================================================
    // MARK: - Shit
    // ======================================================

    private func hitShit(
        _ object:
            PlacedMapObject
    ) {

        score -= 5

        statusText =
            "Shit hit"


        // Remove Shit from the current game session.
        activeMapObjects.removeAll {
            $0.id == object.id
        }


        print(
            "# GAME | Shit hit"
        )

        print(
            "# GAME | Score: \(score)"
        )


        startShitEffect()
    }


    // ======================================================
    // MARK: - Shit Effect
    // ======================================================

    private func startShitEffect() {

        // Stop an already running effect.
        shitEffectTask?
            .cancel()


        isLeavingShitTrail =
            true


        shitEffectTask =
            Task { @MainActor in

                let endDate =
                    Date()
                        .addingTimeInterval(
                            10
                        )


                while Date() < endDate {

                    // ------------------------------------------
                    // Random delay: 0.5 - 2 seconds
                    // ------------------------------------------

                    let delay =
                        Double.random(
                            in:
                                0.5...2.0
                        )


                    try? await Task.sleep(
                        for:
                            .seconds(
                                delay
                            )
                    )


                    guard Task.isCancelled == false
                    else {
                        return
                    }


                    guard Date() < endDate
                    else {
                        break
                    }


                    // ------------------------------------------
                    // Current robot position
                    // ------------------------------------------

                    let pose =
                        currentRobotPose


                    // ------------------------------------------
                    // Random size: 0.5 - 3 cm radius
                    // ------------------------------------------

                    let radius =
                        Float.random(
                            in:
                                0.005...0.03
                        )


                    shitDots.append(
                        ShitDot(
                            position:
                                SIMD2<Float>(
                                    pose.position.x,
                                    pose.position.z
                                ),

                            radius:
                                radius
                        )
                    )


                    print(
                        "# GAME | Shit dropped"
                    )
                }


                isLeavingShitTrail =
                    false


                print(
                    "# GAME | Shit effect ended"
                )
            }
    }


    // ======================================================
    // MARK: - Oil
    // ======================================================

    private func hitOil() {

        score -= 5

        statusText =
            "Oil hit"


        print(
            "# GAME | Oil hit"
        )

        print(
            "# GAME | Score: \(score)"
        )


        // Later:
        //
        // RobotController:
        // disable joystick temporarily
        // and rotate Eduard for several seconds.
    }


    // ======================================================
    // MARK: - Water
    // ======================================================

    private func hitWater() {

        score -= 2

        statusText =
            "Water hit"


        print(
            "# GAME | Water hit"
        )

        print(
            "# GAME | Score: \(score)"
        )


        // Later:
        //
        // RobotController:
        // temporarily reduce movement speed.
    }


    // ======================================================
    // MARK: - Rock
    // ======================================================

    private func hitRock() {

        score -= 5

        statusText =
            "Rock hit"


        print(
            "# GAME | Rock hit"
        )

        print(
            "# GAME | Score: \(score)"
        )


        // Later:
        //
        // RobotController:
        // temporarily stop Eduard.
    }


    // ======================================================
    // MARK: - Tree
    // ======================================================

    private func hitTree() {

        score -= 5

        statusText =
            "Tree hit"


        print(
            "# GAME | Tree hit"
        )

        print(
            "# GAME | Score: \(score)"
        )
    }


    // ======================================================
    // MARK: - Tongue
    // ======================================================

    private func hitTongue() {

        score += 5

        statusText =
            "Tongue collected"


        print(
            "# GAME | Tongue hit"
        )

        print(
            "# GAME | Score: \(score)"
        )
    }


    // ======================================================
    // MARK: - Reset
    // ======================================================

    func reset(
        map:
            GameMap
    ) {

        score =
            0

        collectedEggs =
            0

        statusText =
            ""

        activeMapObjects =
            map.mapObjects

        shitEffectTask?
            .cancel()

        shitEffectTask =
            nil

        isLeavingShitTrail =
            false

        shitDots
            .removeAll()

        currentRobotPose =
            .zero

        collisionManager
            .reset()


        print(
            "# GAME | Reset"
        )
    }
}
