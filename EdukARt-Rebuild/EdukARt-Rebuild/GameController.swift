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
import UIKit


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


// MARK: - Game Coin

struct GameCoin:
    Identifiable {

    let id:
        UUID

    let position:
        SIMD2<Float>
}


// MARK: - Game Result

struct GameResult:
    Identifiable,
    Codable {

    let id:
        UUID

    let playerName:
        String

    let finishedAt:
        Date

    let trackName:
        String

    let elapsedTime:
        TimeInterval

    let collectedCoins:
        Int

    let deliveredEggs:
        Int?

    let oilHits:
        Int

    let shitHits:
        Int

    let score:
        Int
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

    @Published private(set)
    var revealedTreeIDs:
        Set<UUID> = []

    @Published private(set)
    var coins:
        [GameCoin] = []

    @Published private(set)
    var collectedCoins:
        Int = 0

    @Published private(set)
    var oilHits:
        Int = 0

    @Published private(set)
    var shitHits:
        Int = 0

    @Published private(set)
    var isRaceRunning:
        Bool = false

    @Published private(set)
    var isRaceFinished:
        Bool = false

    @Published private(set)
    var elapsedTime:
        TimeInterval = 0

    @Published private(set)
    var leaderboard:
        [GameResult] = []

    @Published private(set)
    var bestTimeBonusEarned:
        Bool = false

    // ======================================================
    // MARK: - Eggs
    // ======================================================

    /// Eggs currently carried by Eduard or already delivered.
    @Published private(set)
    var runtimeEggs:
        [RuntimeEgg] = []


    /// Number of eggs successfully delivered to Egg Cup.
    @Published private(set)
    var deliveredEggs:
        Int = 0


    /// Latest robot pose used by gameplay.
    ///
    /// CameraARView uses this pose to place carried eggs
    /// on the physical or simulated Eduard.
    @Published private(set)
    var latestRobotPose:
        RobotPose?


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

    private var onTreeEffectStarted:
        ((TimeInterval) -> Void)?

    private var latestRobotPoses:
        [CollisionActor: RobotPose] = [:]

    private var shitEffectActor:
        CollisionActor = .simulation


    private var carriedEggCount:
        Int {

        runtimeEggs.filter {

            if case .carried =
                $0.state {

                return true
            }

            return false
        }
        .count
    }

    private let shitEffectDuration:
        TimeInterval = 10

    private let shitDotSpawnDistance:
        Float = 0.14

    private var oilCooldownEndDates:
        [UUID: Date] = [:]

    private let oilCooldownDuration:
        TimeInterval = 20

    private static let coinSpacing:
        Float = 0.50

    private static let firstCoinDistance:
        Float = 0.50

    private let coinCollisionRadius:
        Float = 0.035

    private let finishCollisionRadius:
        Float = 0.35

    private let startClearRadius:
        Float = 0.45

    private let treeLightEffectDuration:
        TimeInterval = 1.0

    private let eggDeliveryScore:
        Int = 300

    private let undeliveredEggPenalty:
        Int = 600

    private let map:
        GameMap

    private var raceStartDate:
        Date?

    private var hasLeftStartArea:
        Bool = false

    private var timerTask:
        Task<Void, Never>?


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

        self.map =
            map

        // Runtime copy.
        //
        // The stored map itself is not modified.
        self.activeMapObjects =
            map.mapObjects

        self.coins =
            Self.generateCoins(
                from:
                    map.trackPoints
            )

        loadLeaderboard()
    }


    deinit {

        timerTask?
            .cancel()

        shitEffectTask?
            .cancel()
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


    func setTreeEffectHandler(
        _ handler: @escaping (TimeInterval) -> Void
    ) {

        onTreeEffectStarted =
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

        switch actor {

        case .real:

            latestRobotPose =
                pose

        case .simulation:

            if latestRobotPoses[.real]
                == nil {

                latestRobotPose =
                    pose
            }
        }

        updateOilCooldowns()

        let collidableObjects =
            activeMapObjects.filter { object in

                if object.type == .oil,
                   oilCooldownEndDates[
                    object.id
                   ] != nil {

                    return false
                }

                if object.type == .tree,
                   revealedTreeIDs.contains(
                    object.id
                   ) == false {

                    return false
                }

                return true
            }

        let collisions =
            collisionManager.update(
                actor:
                    actor,

                robotPose:
                    pose,

                objects:
                    collidableObjects
            )


        // --------------------------------------------------
        // Handle collision events
        // --------------------------------------------------

        for collision in collisions {

            handleCollision(
                collision
            )
        }

        collectCoins(
            robotPose:
                pose,

            actor:
                actor
        )

        updateFinishState(
            robotPose:
                pose
        )
    }


    func startRace() {

        guard isRaceRunning == false
        else {
            return
        }

        score =
            0

        elapsedTime =
            0

        raceStartDate =
            Date()

        hasLeftStartArea =
            false

        bestTimeBonusEarned =
            false

        isRaceFinished =
            false

        isRaceRunning =
            true

        timerTask?
            .cancel()

        timerTask =
            Task { @MainActor [weak self] in

                while Task.isCancelled == false {

                    self?.updateElapsedTime()

                    try? await Task.sleep(
                        for:
                            .seconds(
                                0.05
                            )
                    )
                }
            }
    }


    func saveFinishedResult(
        playerName:
            String
    ) {

        guard isRaceFinished
        else {
            return
        }

        let trimmedName =
            playerName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let result =
            GameResult(
                id:
                    UUID(),

                playerName:
                    trimmedName.isEmpty
                    ? "Player"
                    : trimmedName,

                finishedAt:
                    Date(),

                trackName:
                    map.name,

                elapsedTime:
                    elapsedTime,

                collectedCoins:
                    collectedCoins,

                deliveredEggs:
                    deliveredEggs,

                oilHits:
                    oilHits,

                shitHits:
                    shitHits,

                score:
                    score
            )

        leaderboard.append(
            result
        )

        leaderboard.sort {

            if $0.score == $1.score {

                return $0.elapsedTime < $1.elapsedTime
            }

            return $0.score > $1.score
        }

        saveLeaderboard()
    }


    private func collectCoins(
        robotPose:
            RobotPose,

        actor:
            CollisionActor
    ) {

        let collisionDistance =
            collisionManager.robotRadius
            +
            coinCollisionRadius

        let collisionDistanceSquared =
            collisionDistance
            *
            collisionDistance

        let collectedIDs =
            coins.compactMap { coin -> UUID? in

                let dx =
                    robotPose.position.x
                    -
                    coin.position.x

                let dz =
                    robotPose.position.z
                    -
                    coin.position.y

                let distanceSquared =
                    dx * dx
                    +
                    dz * dz

                return distanceSquared <= collisionDistanceSquared
                    ? coin.id
                    : nil
            }

        guard collectedIDs.isEmpty == false
        else {
            return
        }

        let collectedIDSet =
            Set(
                collectedIDs
            )

        coins.removeAll {
            collectedIDSet.contains(
                $0.id
            )
        }

        collectedCoins +=
            collectedIDs.count

        score +=
            collectedIDs.count
            *
            100

        triggerGameplayFeedback(
            .success
        )

        print(
            "# GAME | Coin collected by \(actor.rawValue) | Coins: \(collectedCoins)"
        )
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
        // Tree Trigger
        // --------------------------------------------------

        case .treeTrigger:

            triggerTree(
                object
            )


        // --------------------------------------------------
        // Egg Cup
        // --------------------------------------------------

        case .eggCup:

            deliverEggsToEggCup()
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
    // MARK: - Collect Egg
    // ======================================================

    private func collectEggs(
        _ object:
            PlacedMapObject
    ) {

        // --------------------------------------------------
        // Add runtime egg
        // --------------------------------------------------

        let slot =
            carriedEggCount


        let egg =
            RuntimeEgg(
                id:
                    object.id,

                state:
                    .carried(
                        slot:
                            slot
                    )
            )


        runtimeEggs.append(
            egg
        )


        // --------------------------------------------------
        // Remove original floor egg from runtime map
        // --------------------------------------------------
        //
        // It is NOT deleted from the saved GameMap.
        // --------------------------------------------------

        activeMapObjects
            .removeAll {

                $0.id
                    == object.id
            }


        collectedEggs =
            slot
            + 1

        statusText =
            "Egg collected"


        print(
            "# EGG | Collected | carrying \(collectedEggs)"
        )
    }


    // ======================================================
    // MARK: - Deliver Eggs to Egg Cup
    // ======================================================

    private func deliverEggsToEggCup() {

        // All currently carried eggs.
        let carriedIndices =
            runtimeEggs.indices.filter {

                if case .carried =
                    runtimeEggs[$0].state {

                    return true
                }

                return false
            }


        guard carriedIndices.isEmpty
                == false
        else {

            statusText =
                "No eggs to deliver"

            return
        }


        // Existing eggs on Egg Cup determine
        // the next visual slot.
        var nextDeliveredSlot =
            deliveredEggs


        var deliveredNow =
            0


        for index in carriedIndices {

            runtimeEggs[index].state =
                .delivered(
                    slot:
                        nextDeliveredSlot
                )

            nextDeliveredSlot +=
                1

            deliveredNow +=
                1
        }


        // --------------------------------------------------
        // Score
        // --------------------------------------------------

        score +=
            deliveredNow
            * eggDeliveryScore


        deliveredEggs +=
            deliveredNow


        collectedEggs =
            0


        statusText =
            "\(deliveredNow) egg(s) delivered"


        print(
            "# EGG CUP | Delivered:",
            deliveredNow
        )

        print(
            "# EGG CUP | Total delivered:",
            deliveredEggs
        )

        print(
            "# GAME | Score:",
            score
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

        shitHits += 1

        score -= 50

        triggerGameplayFeedback(
            .warning
        )

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

        oilHits += 1

        triggerGameplayFeedback(
            .warning
        )

        statusText =
            "Oil hit"

        print(
            "# GAME | Oil hit"
        )

        print(
            "# GAME | Score: \(score)"
        )

        startOilCooldown(
            for:
                object
        )

        onOilEffectStarted?(
            5
        )
    }


    private func startOilCooldown(
        for object:
            PlacedMapObject
    ) {

        oilCooldownEndDates[
            object.id
        ] =
            Date()
                .addingTimeInterval(
                    oilCooldownDuration
                )

        updateOilCooldowns()

        Task { @MainActor [weak self] in

            guard let self
            else {
                return
            }

            try? await Task.sleep(
                for:
                    .seconds(
                        self.oilCooldownDuration
                    )
            )

            self.updateOilCooldowns()
        }
    }


    private func updateOilCooldowns() {

        let now =
            Date()

        oilCooldownEndDates =
            oilCooldownEndDates.filter {
                $0.value > now
            }

    }


    // ======================================================
    // MARK: - Haptic Feedback
    // ======================================================

    private func triggerGameplayFeedback(
        _ type:
            UINotificationFeedbackGenerator.FeedbackType
    ) {

        let generator =
            UINotificationFeedbackGenerator()

        generator.prepare()

        generator.notificationOccurred(
            type
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

        onTreeEffectStarted?(
            treeLightEffectDuration
        )

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
    // MARK: - Trigger Tree
    // ======================================================

    private func triggerTree(
        _ trigger:
            PlacedMapObject
    ) {

        guard let tree =
            nearestHiddenTree(
                to:
                    trigger
            )
        else {
            return
        }


        revealedTreeIDs.insert(
            tree.id
        )

        activeMapObjects.removeAll {
            $0.id == trigger.id
        }

        print(
            "# TREE | Triggered | tree \(tree.id) | trigger \(trigger.id)"
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

        collectedCoins =
            0

        collectedEggs =
            0

        runtimeEggs
            .removeAll()

        deliveredEggs =
            0

        latestRobotPose =
            nil

        oilHits =
            0

        shitHits =
            0

        elapsedTime =
            0

        isRaceRunning =
            false

        isRaceFinished =
            false

        raceStartDate =
            nil

        hasLeftStartArea =
            false

        bestTimeBonusEarned =
            false

        timerTask?
            .cancel()

        timerTask =
            nil

        statusText =
            ""

        activeMapObjects =
            map.mapObjects

        coins =
            Self.generateCoins(
                from:
                    map.trackPoints
            )

        shitEffectTask?
            .cancel()

        shitEffectTask =
            nil

        isLeavingShitTrail =
            false

        shitDots
            .removeAll()

        revealedTreeIDs
            .removeAll()

        oilCooldownEndDates
            .removeAll()

        latestRobotPoses
            .removeAll()

        collisionManager
            .reset()


        print(
            "# GAME | Reset"
        )
    }


    private func updateElapsedTime() {

        guard let raceStartDate,
              isRaceRunning
        else {
            return
        }

        elapsedTime =
            Date()
                .timeIntervalSince(
                    raceStartDate
                )
    }


    private func updateFinishState(
        robotPose:
            RobotPose
    ) {

        guard isRaceRunning,
              isRaceFinished == false,
              let startPoint =
                map.trackPoints.first,
              let finishPoint =
                map.trackPoints.last
        else {
            return
        }

        let startDistance =
            distance(
                from:
                    robotPose,
                to:
                    startPoint
            )

        if startDistance > startClearRadius {

            hasLeftStartArea =
                true
        }

        guard hasLeftStartArea
        else {
            return
        }

        let finishDistance =
            distance(
                from:
                    robotPose,
                to:
                    finishPoint
            )

        guard finishDistance <= finishCollisionRadius
        else {
            return
        }

        finishRace()
    }


    private func finishRace() {

        updateElapsedTime()

        isRaceRunning =
            false

        isRaceFinished =
            true

        timerTask?
            .cancel()

        timerTask =
            nil

        score +=
            1000

        bestTimeBonusEarned =
            isNewBestTime

        if bestTimeBonusEarned {

            score +=
                10
        }

        let remainingEggs =
            carriedEggCount

        if remainingEggs > 0 {

            let penalty =
                remainingEggs
                * undeliveredEggPenalty

            score -=
                penalty

            statusText =
                "Finished | \(remainingEggs) egg penalty"

            print(
                "# GAME | Undelivered eggs penalty | Eggs:",
                remainingEggs,
                "| Penalty:",
                penalty,
                "| Score:",
                score
            )

        } else {

            statusText =
                "Finished"
        }
    }


    private var isNewBestTime:
        Bool {

        guard let bestTime =
            leaderboard
                .map(\.elapsedTime)
                .min()
        else {
            return false
        }

        return elapsedTime < bestTime
    }


    private func distance(
        from pose:
            RobotPose,

        to point:
            StoredTrackPoint
    ) -> Float {

        let dx =
            pose.position.x
            -
            point.x

        let dz =
            pose.position.z
            -
            point.z

        return sqrt(
            dx * dx
            +
            dz * dz
        )
    }


    private func distance(
        from pose:
            RobotPose,

        to point:
            SIMD2<Float>
    ) -> Float {

        let dx =
            pose.position.x
            -
            point.x

        let dz =
            pose.position.z
            -
            point.y

        return sqrt(
            dx * dx
            +
            dz * dz
        )
    }


    private func nearestHiddenTree(
        to trigger:
            PlacedMapObject
    ) -> PlacedMapObject? {

        activeMapObjects
            .filter { object in

                object.type == .tree
                    && revealedTreeIDs.contains(
                        object.id
                    ) == false
            }
            .min { first, second in

                distance(
                    from:
                        first,
                    to:
                        trigger
                )
                <
                distance(
                    from:
                        second,
                    to:
                        trigger
                )
            }
    }


    private func distance(
        from first:
            PlacedMapObject,

        to second:
            PlacedMapObject
    ) -> Float {

        let dx =
            first.x
            -
            second.x

        let dz =
            first.z
            -
            second.z

        return sqrt(
            dx * dx
            +
            dz * dz
        )
    }


    private var leaderboardKey:
        String {

        "leaderboard-\(map.id.uuidString)"
    }


    private func loadLeaderboard() {

        guard let data =
            UserDefaults.standard.data(
                forKey:
                    leaderboardKey
            ),
              let decoded =
                try? JSONDecoder()
                    .decode(
                        [GameResult].self,
                        from:
                            data
                    )
        else {
            return
        }

        leaderboard =
            decoded
    }


    private func saveLeaderboard() {

        guard let data =
            try? JSONEncoder()
                .encode(
                    leaderboard
                )
        else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey:
                leaderboardKey
        )
    }


    private static func generateCoins(
        from trackPoints:
            [StoredTrackPoint]
    ) -> [GameCoin] {

        let points =
            trackPoints.map {
                SIMD2<Float>(
                    $0.x,
                    $0.z
                )
            }

        guard points.count >= 2
        else {
            return []
        }

        var result:
            [GameCoin] = []

        var distanceAlongTrack:
            Float = 0

        var nextCoinDistance =
            firstCoinDistance

        for index in 0..<(points.count - 1) {

            let start =
                points[index]

            let end =
                points[index + 1]

            let segmentLength =
                simd_distance(
                    start,
                    end
                )

            guard segmentLength > 0.001
            else {
                continue
            }

            while distanceAlongTrack + segmentLength >= nextCoinDistance {

                let t =
                    (
                        nextCoinDistance
                        -
                        distanceAlongTrack
                    )
                    /
                    segmentLength

                let position =
                    start
                    +
                    (
                        end
                        -
                        start
                    )
                    *
                    t

                result.append(
                    GameCoin(
                        id:
                            UUID(),

                        position:
                            position
                    )
                )

                nextCoinDistance +=
                    coinSpacing
            }

            distanceAlongTrack +=
                segmentLength
        }

        return result
    }
}
