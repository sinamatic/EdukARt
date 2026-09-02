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

    private var onShitEffectStarted:
        ((TimeInterval) -> Void)?

    private var onOilEffectStarted:
        ((TimeInterval) -> Void)?

    private var latestRobotPoses:
        [CollisionActor: RobotPose] = [:]

    private var shitEffectActor:
        CollisionActor = .simulation

    private let shitEffectDuration:
        TimeInterval = 10

    private let shitDotSpawnDistance:
        Float = 0.14


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


    func setShitEffectHandler(
        _ handler: @escaping (TimeInterval) -> Void
    ) {

        onShitEffectStarted =
            handler
    }


    func setOilEffectHandler(
        _ handler: @escaping (TimeInterval) -> Void
    ) {

        onOilEffectStarted =
            handler
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
            RobotPose,

        actor:
            CollisionActor
    ) {

        latestRobotPoses[actor] =
            pose

        let collisions =
            collisionManager.update(
                actor:
                    actor,

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
                "# COLLISION BEGAN | \(collision.object.type.name) | actor = \(collision.actor.rawValue)"
            )


            handleCollisionBegan(
                with:
                    collision.object,

                actor:
                    collision.actor
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
            PlacedMapObject,

        actor:
            CollisionActor
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
                object,

                actor:
                    actor
            )


        // --------------------------------------------------
        // Oil
        // --------------------------------------------------

        case .oil:

            hitOil(
                object
            )


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
            PlacedMapObject,

        actor:
            CollisionActor
    ) {

        score -= 5

        statusText =
            "Shit hit"


        // Remove Shit from the current game session.
        activeMapObjects.removeAll {
            $0.id == object.id
        }


        print(
            "# GAME | Shit hit | SHIT actor = \(actor.rawValue)"
        )

        print(
            "# GAME | Score: \(score)"
        )


        startShitEffect(
            actor:
                actor
        )
    }


    // ======================================================
    // MARK: - Shit Effect
    // ======================================================

    private func startShitEffect(
        actor:
            CollisionActor
    ) {

        // Stop an already running effect.
        shitEffectTask?
            .cancel()


        isLeavingShitTrail =
            true

        shitEffectActor =
            actor

        onShitEffectStarted?(
            shitEffectDuration
        )


        shitEffectTask =
            Task { @MainActor in

                let endDate =
                    Date()
                        .addingTimeInterval(
                            shitEffectDuration
                        )


                while Date() < endDate {

                    // ------------------------------------------
                    // Random delay: 0.04 - 0.12 seconds
                    // ------------------------------------------

                    let delay =
                        Double.random(
                            in:
                                0.04...0.12
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

                    guard let pose =
                        latestRobotPoses[shitEffectActor]
                    else {
                        continue
                    }

                    let dropPosition =
                        shitDotPosition(
                            behind:
                                pose
                        )


                    // ------------------------------------------
                    // Random size: 1.5 - 5 cm radius
                    // ------------------------------------------

                    let radius =
                        Float.random(
                            in:
                                0.015...0.05
                        )


                    shitDots.append(
                        ShitDot(
                            position:
                                dropPosition,

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


    private func shitDotPosition(
        behind pose:
            RobotPose
    ) -> SIMD2<Float> {

        // EduardSimulation defines forward as
        // (-sin(rotation), -cos(rotation)).
        // A negative forward offset therefore places the dot
        // behind the robot in map X/Z coordinates.
        return SIMD2<Float>(
            pose.position.x
                + sin(
                    pose.rotation
                )
                * shitDotSpawnDistance,

            pose.position.z
                + cos(
                    pose.rotation
                )
                * shitDotSpawnDistance
        )
    }


    // ======================================================
    // MARK: - Oil
    // ======================================================

    private func hitOil(
        _ object:
            PlacedMapObject
    ) {

        score -= 5

        statusText =
            "Oil hit"

        activeMapObjects.removeAll {
            $0.id == object.id
        }


        print(
            "# GAME | Oil hit"
        )

        print(
            "# GAME | Score: \(score)"
        )


        onOilEffectStarted?(
            10
        )
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

        latestRobotPoses
            .removeAll()

        collisionManager
            .reset()


        print(
            "# GAME | Reset"
        )
    }
}
