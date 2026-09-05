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


// ======================================================
// MARK: - Game Phase
// ======================================================

enum GamePhase {

    case racing
    case finished
    case freeDrive
}


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

    let totalCoins:
        Int?

    let resultingTime:
        TimeInterval?

    let collectedCoins:
        Int

    let collectedEggs:
        Int?

    let deliveredEggs:
        Int?

    let oilHits:
        Int

    let shitHits:
        Int

    let rockHits:
        Int?

    let treeHits:
        Int?

    let obstacleHits:
        Int?

    let collectedItemboxes:
        Int?

    let finalSpeedPercent:
        Int?

    let minSpeedPercent:
        Int?

    let maxSpeedPercent:
        Int?

    let score:
        Int
}


@MainActor
final class GameController:
    ObservableObject {

    // ======================================================
    // MARK: - Published Game State
    // ======================================================

    /// Legacy score kept for old leaderboard entries.
    /// New gameplay uses elapsed time only.
    @Published private(set)
    var score:
        Int = 0

    @Published private(set)
    var phase:
        GamePhase = .racing


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
    var totalCoins:
        Int = 0

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
    var rockHits:
        Int = 0

    @Published private(set)
    var treeHits:
        Int = 0

    @Published private(set)
    var obstacleHits:
        Int = 0

    @Published private(set)
    var collectedItemboxes:
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

    private var onWaterModeChanged:
        ((Bool) -> Void)?

    private var onCoinCollected:
        (() -> Void)?

    private var onItemboxCollected:
        (() -> Void)?

    private var onEggCollected:
        (() -> Void)?

    private var onEggsDelivered:
        (() -> Void)?

    private var currentSpeedPercentProvider:
        (() -> Int)?

    private var minSpeedPercentProvider:
        (() -> Int)?

    private var maxSpeedPercentProvider:
        (() -> Int)?

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
        TimeInterval = 5

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
        TimeInterval = 3.0

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

        let generatedCoins =
            Self.generateCoins(
                from:
                    map.trackPoints
            )

        self.coins =
            generatedCoins

        self.totalCoins =
            generatedCoins.count

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


    func setWaterModeHandler(
        _ handler: @escaping (Bool) -> Void
    ) {

        onWaterModeChanged =
            handler
    }


    func setCoinCollectedHandler(
        _ handler: @escaping () -> Void
    ) {

        onCoinCollected =
            handler
    }


    func setItemboxCollectedHandler(
        _ handler: @escaping () -> Void
    ) {

        onItemboxCollected =
            handler
    }


    func setEggCollectedHandler(
        _ handler: @escaping () -> Void
    ) {

        onEggCollected =
            handler
    }


    func setEggsDeliveredHandler(
        _ handler: @escaping () -> Void
    ) {

        onEggsDelivered =
            handler
    }


    func setCurrentSpeedPercentProvider(
        _ provider: @escaping () -> Int
    ) {

        currentSpeedPercentProvider =
            provider
    }


    func setMinSpeedPercentProvider(
        _ provider: @escaping () -> Int
    ) {

        minSpeedPercentProvider =
            provider
    }


    func setMaxSpeedPercentProvider(
        _ provider: @escaping () -> Int
    ) {

        maxSpeedPercentProvider =
            provider
    }


    func recordObstacleDamage(
        type:
            MapObjectType
    ) {

        guard phase == .racing
        else {
            return
        }

        obstacleHits +=
            1

        switch type {

        case .rock:
            rockHits +=
                1

        case .tree:
            treeHits +=
                1

        default:
            break
        }

        triggerGameplayFeedback(
            .warning
        )

        statusText =
            "\(type.name) damage"

        print(
            "# GAME | Obstacle damage | \(type.name) | total \(obstacleHits)"
        )
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

        guard isRaceRunning == false,
              phase == .racing
        else {
            return
        }

        score =
            0

        elapsedTime =
            0

        phase =
            .racing

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

        guard phase == .finished
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

                totalCoins:
                    totalCoins,

                resultingTime:
                    resultingTime,

                collectedCoins:
                    collectedCoins,

                collectedEggs:
                    collectedEggs,

                deliveredEggs:
                    deliveredEggs,

                oilHits:
                    oilHits,

                shitHits:
                    shitHits,

                rockHits:
                    rockHits,

                treeHits:
                    treeHits,

                obstacleHits:
                    obstacleHits,

                collectedItemboxes:
                    collectedItemboxes,

                finalSpeedPercent:
                    currentSpeedPercentProvider?(),

                minSpeedPercent:
                    minSpeedPercentProvider?(),

                maxSpeedPercent:
                    maxSpeedPercentProvider?(),

                score:
                    0
            )

        leaderboard.append(
            result
        )

        leaderboard.sort {
            Self.rankingTime(
                for:
                    $0
            )
            <
            Self.rankingTime(
                for:
                    $1
            )
        }

        saveLeaderboard()
    }


    func continueAfterFinish() {

        guard phase == .finished
        else {
            return
        }


        phase =
            .freeDrive

        isRaceRunning =
            false

        isRaceFinished =
            false

        statusText =
            ""

        collisionManager
            .reset()

        print(
            "# GAME | Free drive"
        )
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

        onCoinCollected?()

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


    var isScoringEnabled: Bool {

        phase == .racing
    }


    var isRaceActive: Bool {

        phase == .racing
    }


    var missingCoins:
        Int {

        max(
            totalCoins - collectedCoins,
            0
        )
    }


    var coinTimePenalty:
        TimeInterval {

        TimeInterval(
            missingCoins * 5
        )
    }


    var itemboxTimeBonus:
        TimeInterval {

        TimeInterval(
            collectedItemboxes * 20
        )
    }


    var resultingTime:
        TimeInterval {

        max(
            elapsedTime
            +
            coinTimePenalty
            -
            itemboxTimeBonus,
            0
        )
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
        // Itembox
        // --------------------------------------------------

        case .itembox:

            collectItembox(
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

            deliverEggsToEggCup(
                object
            )
        }
    }


    // ======================================================
    // MARK: - Collision Ended
    // ======================================================

    private func handleCollisionEnded(
        with object:
            PlacedMapObject
    ) {

        switch object.type {

        case .water:

            onWaterModeChanged?(
                false
            )

            statusText =
                ""

            print(
                "# GAME | Left water"
            )

        default:
            break
        }
    }


    // ======================================================
    // MARK: - Collect Itembox
    // ======================================================

    private func collectItembox(
        _ object:
            PlacedMapObject
    ) {

        activeMapObjects.removeAll {
            $0.id == object.id
        }

        collectedItemboxes +=
            1

        statusText =
            "Itembox collected"

        onItemboxCollected?()

        print(
            "# ITEMBOX | Collected | bonus -20s"
        )
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

        onEggCollected?()


        print(
            "# EGG | Collected | carrying \(collectedEggs)"
        )
    }


    // ======================================================
    // MARK: - Deliver Eggs to Egg Cup
    // ======================================================

    private func deliverEggsToEggCup(
        _ eggCup:
            PlacedMapObject
    ) {

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
                    eggCupID:
                        eggCup.id,

                    slot:
                        nextDeliveredSlot
                )

            nextDeliveredSlot +=
                1

            deliveredNow +=
                1
        }


        deliveredEggs +=
            deliveredNow

        onEggsDelivered?()


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


        startShitTrail(
            actor:
                actor
        )

        onShitEffectStarted?(
            shitEffectDuration
        )
    }


    // ======================================================
    // MARK: - Shit Trail
    // ======================================================

    private func startShitTrail(
        actor:
            CollisionActor
    ) {

        shitEffectTask?
            .cancel()

        shitEffectActor =
            actor

        shitEffectTask =
            Task { @MainActor in

                let endDate =
                    Date()
                        .addingTimeInterval(
                            shitEffectDuration
                        )


                while Date() < endDate {

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


                    guard Task.isCancelled == false,
                          Date() < endDate
                    else {
                        return
                    }


                    guard let pose =
                        latestRobotPoses[
                            shitEffectActor
                        ]
                    else {
                        continue
                    }


                    shitDots.append(
                        ShitDot(
                            position:
                                shitDotPosition(
                                    behind:
                                        pose
                                ),
                            radius:
                                Float.random(
                                    in:
                                        0.015...0.05
                                )
                        )
                    )
                }


                shitEffectTask =
                    nil
            }
    }


    private func shitDotPosition(
        behind pose:
            RobotPose
    ) -> SIMD2<Float> {

        SIMD2<Float>(
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

        statusText =
            "Swimming"

        onWaterModeChanged?(
            true
        )


        print(
            "# GAME | Entered water"
        )
    }


    // ======================================================
    // MARK: - Rock
    // ======================================================

    private func hitRock() {

        statusText =
            "Rock hit"


        print(
            "# GAME | Rock hit"
        )
    }


    // ======================================================
    // MARK: - Tree
    // ======================================================

    private func hitTree() {

        onTreeEffectStarted?(
            treeLightEffectDuration
        )

        statusText =
            "Tree hit"


        print(
            "# GAME | Tree hit"
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

        onTreeEffectStarted?(
            treeLightEffectDuration
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

        phase =
            .racing

        score =
            0

        collectedCoins =
            0

        totalCoins =
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

        rockHits =
            0

        treeHits =
            0

        obstacleHits =
            0

        collectedItemboxes =
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

        onWaterModeChanged?(
            false
        )

        activeMapObjects =
            map.mapObjects

        let generatedCoins =
            Self.generateCoins(
                from:
                    map.trackPoints
            )

        coins =
            generatedCoins

        totalCoins =
            generatedCoins.count

        shitEffectTask?
            .cancel()

        shitEffectTask =
            nil

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

        guard phase == .racing,
              isRaceRunning,
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

        guard phase == .racing
        else {
            return
        }

        updateElapsedTime()

        phase =
            .finished

        isRaceRunning =
            false

        isRaceFinished =
            true

        timerTask?
            .cancel()

        timerTask =
            nil

        bestTimeBonusEarned =
            isNewBestTime

        statusText =
            "Finished"
    }


    private var isNewBestTime:
        Bool {

        guard let bestTime =
            leaderboard
                .map({
                    Self.rankingTime(
                        for:
                            $0
                    )
                })
                .min()
        else {
            return false
        }

        return resultingTime < bestTime
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

        leaderboard.sort {
            Self.rankingTime(
                for:
                    $0
            )
            <
            Self.rankingTime(
                for:
                    $1
            )
        }
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


    private static func rankingTime(
        for result:
            GameResult
    ) -> TimeInterval {

        result.resultingTime
        ??
        result.elapsedTime
    }
}
