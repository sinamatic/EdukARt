//
//  SceneCoordinator.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import ARKit
import RealityKit
import UIKit

enum RealRobotTrackingConstants {
    static let robotTagName = "tag36h11-1"
    static let tagHeightOffset: Float = 0.10
    static let trackingLossGracePeriod: TimeInterval = 2.5
    static let imageForwardSign: Float = -1
}

final class SceneCoordinator: NSObject, ARSessionDelegate {
    private let anchorEntity = AnchorEntity(world: matrix_identity_float4x4)
    var debugController: SceneDebugController?
    private let playerEntity = Entity()
    private let playerModelPitchCorrection = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
    private let mapStartRobotOrientation = simd_quatf(angle: -.pi / 2, axis: [0, 1, 0])
    private let tagOverlayView = AprilTagOverlayView()
    private let wheelRadiansPerMeter: Float = (1000 / (3.14 * 100)) * (2 * .pi)
    private let wheelSpinAxis = SIMD3<Float>(1, 0, 0)
    private weak var frontLeftWheelEntity: Entity?
    private weak var frontRightWheelEntity: Entity?
    private weak var backLeftWheelEntity: Entity?
    private weak var backRightWheelEntity: Entity?
    private var frontLeftWheelSpin: Float = 0
    private var frontRightWheelSpin: Float = 0
    private var backLeftWheelSpin: Float = 0
    private var backRightWheelSpin: Float = 0
    private var lastWheelRobotPosition: SIMD3<Float>?
    private var lastWheelRobotYaw: Float?
    private var simulatedRobotBaseOrientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
    private var realWorldCollisionShape: ShapeResource?
    private var coinObstacleProbeShape: ShapeResource?
    private var obstacleEntities: [UUID: Entity] = [:]
    private var collectibleTemplates: [String: Entity] = [:]
    private weak var game: Game?
    private weak var arView: ARView?
    private var lastRealRobotDetectionDate = Date.distantPast
    private var realRobotOrientation: simd_quatf?
    private var hasScheduledInitialObstacles = false
    private var hasLoadedInitialObstacles = false
    private var lastVisibleCoinSpawnDate = Date.distantPast
    private var isSceneAnchorAdded = false
    private var mapOriginReferenceTagName: String?
    private var mapOriginReferenceTagNumber: String?
    private var isWaitingForMapOrigin = false
    private var hasAlignedMapOrigin = false
    private var hasStartedGameplayTracking = false
    private var isWaitingForRealRobotPlacement = false
    private var hasPlacedRealRobot = false
    private var hasNotifiedCameraFrameAvailable = false
    var onCameraFrameAvailable: (() -> Void)?

    func attach(to arView: ARView) {
        self.arView = arView
        attachTagOverlay(to: arView)
    }

    func configureMapOriginTracking(_ configuration: ARWorldTrackingConfiguration, for map: StoredFloorMap?) -> Bool {
        guard let referenceTagName = map?.activeReferenceTagName else {
            mapOriginReferenceTagName = nil
            mapOriginReferenceTagNumber = nil
            isWaitingForMapOrigin = false
            return false
        }

        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AprilTags", bundle: nil) else {
            return false
        }

        let requiredImages = referenceImages.filter { $0.name == referenceTagName }
        guard requiredImages.isEmpty == false else {
            return false
        }

        mapOriginReferenceTagName = referenceTagName
        mapOriginReferenceTagNumber = map?.displayReferenceTagNumber
        isWaitingForMapOrigin = true
        configuration.detectionImages = Set(requiredImages)
        configuration.maximumNumberOfTrackedImages = 1
        configuration.isAutoFocusEnabled = true
        configuration.automaticImageScaleEstimationEnabled = false
        return true
    }

    func prepareScene(from game: Game) {
        self.game = game
        addPlayer(from: game.currentRobot)
    }

    func markSceneAnchorAdded() {
        isSceneAnchorAdded = true
    }
    
    func makeScene(from game: Game) -> AnchorEntity {
        self.game = game
        addPlayer(from: game.currentRobot)
        return anchorEntity
    }
    
    func updateScene(from game: Game, in arView: ARView) {
        if arView.scene.anchors.isEmpty {
            guard isWaitingForMapOrigin == false || hasAlignedMapOrigin else {
                return
            }

            arView.scene.anchors.append(makeScene(from: game))
            markSceneAnchorAdded()
            return
        }
        
        setPlayerVisibility(isVisible: game.isRealRobotTracked == false)
        if game.isWaitingForRealRobot {
            startRealRobotPlacementTrackingIfNeeded()
        }
        if game.isRealRobotTracked == false {
            updateWheelRotation(for: game.currentRobot.position, yaw: game.robotYaw)
        }
        playerEntity.position = game.currentRobot.position
        if let realRobotOrientation {
            playerEntity.orientation = realRobotOrientation
        } else {
            playerEntity.orientation = simulatedRobotBaseOrientation * simd_quatf(angle: game.robotYaw, axis: [0, 1, 0])
        }
        if hasLoadedInitialObstacles {
            syncObstacles(from: game.obstacles)
        }
    }

    func loadInitialObstacles(from game: Game) {
        scheduleInitialObstaclesIfNeeded(for: game)
    }

    func configureRealRobotTracking(_ configuration: ARWorldTrackingConfiguration) {
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AprilTags", bundle: nil) else {
            return
        }

        let robotReferenceImages = referenceImages.filter { $0.name == RealRobotTrackingConstants.robotTagName }
        guard robotReferenceImages.isEmpty == false else {
            return
        }

        configuration.detectionImages = Set(robotReferenceImages)
        configuration.maximumNumberOfTrackedImages = 1
        configuration.automaticImageScaleEstimationEnabled = false
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        notifyCameraFrameAvailableIfNeeded()

        guard let game else {
            return
        }

        if updateMapOriginIfNeeded(in: frame) {
            return
        }

        guard isWaitingForMapOrigin == false || hasAlignedMapOrigin else {
            return
        }

        scheduleInitialObstaclesIfNeeded(for: game)

        guard game.isWaitingForRealRobot || game.isRealRobotTracked else {
            return
        }

        guard let robotAnchor = frame.anchors
            .compactMap({ $0 as? ARImageAnchor })
            .first(where: { imageAnchor in
                imageAnchor.isTracked &&
                imageAnchor.referenceImage.name == RealRobotTrackingConstants.robotTagName
            }) else {
            clearRealRobotTrackingIfNeeded()
            return
        }

        lastRealRobotDetectionDate = Date()

        let robotPose = makeRealRobotPose(from: robotAnchor.transform)
        realRobotOrientation = robotPose.orientation

        Task { @MainActor in
            game.syncRealRobot(
                tagName: robotAnchor.referenceImage.name ?? "AprilTag",
                position: robotPose.position
            )
        }
    }

    private func notifyCameraFrameAvailableIfNeeded() {
        guard hasNotifiedCameraFrameAvailable == false else {
            return
        }

        hasNotifiedCameraFrameAvailable = true
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.onCameraFrameAvailable?()
            if self.isWaitingForMapOrigin == false {
                self.arView?.session.delegate = nil
            }
        }
    }

    private func updateMapOriginIfNeeded(in frame: ARFrame) -> Bool {
        guard isWaitingForMapOrigin,
              hasAlignedMapOrigin == false,
              let mapOriginReferenceTagName else {
            return false
        }

        guard let tagAnchor = frame.anchors
            .compactMap({ $0 as? ARImageAnchor })
            .first(where: { imageAnchor in
                imageAnchor.isTracked &&
                imageAnchor.referenceImage.name == mapOriginReferenceTagName
            }) else {
            Task { @MainActor [weak self] in
                self?.tagOverlayView.clear()
            }
            return true
        }

        updateMapOriginOverlay(for: tagAnchor, in: frame)

        anchorEntity.setTransformMatrix(tagAnchor.transform, relativeTo: nil)
        playerEntity.position = .zero
        simulatedRobotBaseOrientation = mapStartRobotOrientation
        playerEntity.orientation = simulatedRobotBaseOrientation
        hasAlignedMapOrigin = true

        if let arView, isSceneAnchorAdded == false {
            arView.scene.anchors.append(anchorEntity)
            isSceneAnchorAdded = true
        }

        startGameplayTrackingIfNeeded()

        if let game {
            Task { @MainActor in
                game.markMapOriginAligned()
            }
            scheduleInitialObstaclesIfNeeded(for: game)
        }

        finishMapOriginTracking()

        return false
    }

    private func startGameplayTrackingIfNeeded() {
        guard hasStartedGameplayTracking == false,
              let arView else {
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .none
        debugController?.configureSession(configuration)
        arView.session.run(configuration, options: [])
        hasStartedGameplayTracking = true
    }

    private func startRealRobotPlacementTrackingIfNeeded() {
        guard isWaitingForRealRobotPlacement == false,
              let arView else {
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .none
        configureRealRobotTracking(configuration)
        debugController?.configureSession(configuration)
        arView.session.delegate = self
        arView.session.run(configuration, options: [])
        isWaitingForRealRobotPlacement = true
        lastRealRobotDetectionDate = Date()
    }

    private func finishMapOriginTracking() {
        isWaitingForMapOrigin = false
        mapOriginReferenceTagName = nil
        mapOriginReferenceTagNumber = nil

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.tagOverlayView.clear()
            self.tagOverlayView.removeFromSuperview()
            self.arView?.session.delegate = nil
        }
    }

    private func attachTagOverlay(to arView: ARView) {
        guard tagOverlayView.superview !== arView else {
            return
        }

        tagOverlayView.translatesAutoresizingMaskIntoConstraints = false
        tagOverlayView.isUserInteractionEnabled = false
        arView.addSubview(tagOverlayView)

        NSLayoutConstraint.activate([
            tagOverlayView.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            tagOverlayView.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            tagOverlayView.topAnchor.constraint(equalTo: arView.topAnchor),
            tagOverlayView.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ])
    }

    private func updateMapOriginOverlay(for anchor: ARImageAnchor, in frame: ARFrame) {
        guard let arView else {
            return
        }

        let detection = AprilTagOverlayDetection(
            corners: projectedCorners(for: anchor, in: arView, frame: frame),
            label: mapOriginReferenceTagNumber ?? displayNumber(for: anchor.referenceImage.name ?? "AprilTag")
        )

        Task { @MainActor [weak self] in
            self?.tagOverlayView.update(detections: [detection])
        }
    }

    private func projectedCorners(for anchor: ARImageAnchor, in arView: ARView, frame: ARFrame) -> [CGPoint] {
        let physicalSize = anchor.referenceImage.physicalSize
        let halfWidth = Float(physicalSize.width / 2)
        let halfHeight = Float(physicalSize.height / 2)

        let localCorners = [
            SIMD4<Float>(-halfWidth, 0, -halfHeight, 1),
            SIMD4<Float>(halfWidth, 0, -halfHeight, 1),
            SIMD4<Float>(halfWidth, 0, halfHeight, 1),
            SIMD4<Float>(-halfWidth, 0, halfHeight, 1)
        ]

        let orientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
        let viewportSize = arView.bounds.size

        return localCorners.map { localCorner in
            let worldCorner = anchor.transform * localCorner
            return frame.camera.projectPoint(
                SIMD3<Float>(worldCorner.x, worldCorner.y, worldCorner.z),
                orientation: orientation,
                viewportSize: viewportSize
            )
        }
    }

    private func displayNumber(for tagName: String) -> String {
        let trailingDigits = tagName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .reversed()
            .prefix(while: { $0.isNumber })
            .reversed()

        guard trailingDigits.isEmpty == false else {
            return tagName
        }

        return "#\(String(trailingDigits))"
    }

    private func scheduleInitialObstaclesIfNeeded(for game: Game) {
        guard hasScheduledInitialObstacles == false else {
            return
        }

        hasScheduledInitialObstacles = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self, weak game] in
            guard let self, let game else {
                return
            }

            self.hasLoadedInitialObstacles = true
            self.addObstacles(from: game.obstacles)
        }
    }

    private func addObstaclesSequentially(_ obstacles: [Obstacle], index: Int = 0) {
        guard index < obstacles.count else {
            hasLoadedInitialObstacles = true
            return
        }

        addObstacles(from: [obstacles[index]])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.addObstaclesSequentially(obstacles, index: index + 1)
        }
    }

    private func clearRealRobotTrackingIfNeeded() {
        guard Date().timeIntervalSince(lastRealRobotDetectionDate) > RealRobotTrackingConstants.trackingLossGracePeriod else {
            return
        }

        realRobotOrientation = nil
        Task { @MainActor [weak game] in
            game?.clearRealRobotTracking()
        }
    }

    private func makeRealRobotPose(from tagWorldTransform: simd_float4x4) -> (position: SIMD3<Float>, orientation: simd_quatf) {
        let tagWorldPosition = SIMD3<Float>(
            tagWorldTransform.columns.3.x,
            tagWorldTransform.columns.3.y,
            tagWorldTransform.columns.3.z
        )
        let tagNormal = simd_normalize(
            SIMD3<Float>(
                tagWorldTransform.columns.1.x,
                tagWorldTransform.columns.1.y,
                tagWorldTransform.columns.1.z
            )
        )
        let robotWorldPosition = tagWorldPosition - (tagNormal * RealRobotTrackingConstants.tagHeightOffset)
        var localRobotPosition = anchorEntity.convert(position: robotWorldPosition, from: nil)
        localRobotPosition.y = max(0, localRobotPosition.y)

        let anchorWorldTransform = anchorEntity.transformMatrix(relativeTo: nil)
        let localTagTransform = anchorWorldTransform.inverse * tagWorldTransform
        let imageForward = simd_normalize(
            SIMD3<Float>(
                localTagTransform.columns.2.x,
                0,
                localTagTransform.columns.2.z
            ) * RealRobotTrackingConstants.imageForwardSign
        )

        guard imageForward.x.isFinite, imageForward.z.isFinite, simd_length(imageForward) > 0.001 else {
            return (localRobotPosition, playerEntity.orientation)
        }

        let yaw = atan2(-imageForward.x, -imageForward.z)
        return (localRobotPosition, simd_quatf(angle: yaw, axis: [0, 1, 0]))
    }
    
    
    private func addPlayer(from player: EduardRobot) {
        guard playerEntity.children.isEmpty else {
            playerEntity.position = player.position
            return
        }
        
        do {
            let chassisEntity = try Entity.load(named: player.chassisModelName)
            chassisEntity.orientation = playerModelPitchCorrection
            
            let frontLeftWheel = makeWheelPivot(from: try Entity.load(named: player.frontLeftWheelModelName))
            let frontRightWheel = makeWheelPivot(from: try Entity.load(named: player.frontRightWheelModelName))
            let backLeftWheel = makeWheelPivot(from: try Entity.load(named: player.backLeftWheelModelName))
            let backRightWheel = makeWheelPivot(from: try Entity.load(named: player.backRightWheelModelName))
            
            frontLeftWheelEntity = frontLeftWheel
            frontRightWheelEntity = frontRightWheel
            backLeftWheelEntity = backLeftWheel
            backRightWheelEntity = backRightWheel
            lastWheelRobotPosition = player.position
            lastWheelRobotYaw = 0

            playerEntity.position = player.position
            simulatedRobotBaseOrientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            playerEntity.orientation = simulatedRobotBaseOrientation
            
            playerEntity.addChild(chassisEntity)
            playerEntity.addChild(frontLeftWheel)
            playerEntity.addChild(frontRightWheel)
            playerEntity.addChild(backLeftWheel)
            playerEntity.addChild(backRightWheel)
            
            // collission box around robot
            playerEntity.components.set(
                CollisionComponent(
                    shapes: [
                        .generateBox(size: player.collisionSize)
                    ]
                )
            )
            
            realWorldCollisionShape = .generateBox(size: SIMD3<Float>(player.collisionSize.x, 0.06, player.collisionSize.z))
            
            let bounds = chassisEntity.visualBounds(relativeTo: playerEntity)
            chassisEntity.position.y -= bounds.min.y
            
            anchorEntity.addChild(playerEntity)
        } catch {
            print("Failed to Load Player: \(error)")
        }
    }

    private func makeWheelPivot(from wheelModel: Entity) -> Entity {
        let wheelContainer = Entity()
        wheelModel.orientation = playerModelPitchCorrection
        wheelContainer.addChild(wheelModel)

        let bounds = wheelContainer.visualBounds(relativeTo: wheelContainer)
        let wheelCenter = (bounds.min + bounds.max) / 2

        let pivot = Entity()
        pivot.position = wheelCenter
        wheelContainer.position = -wheelCenter
        pivot.addChild(wheelContainer)
        return pivot
    }

    private func updateWheelRotation(for robotPosition: SIMD3<Float>, yaw: Float) {
        guard let lastWheelRobotPosition, let lastWheelRobotYaw else {
            self.lastWheelRobotPosition = robotPosition
            self.lastWheelRobotYaw = yaw
            return
        }

        let delta = robotPosition - lastWheelRobotPosition
        let yawDelta = yaw - lastWheelRobotYaw
        self.lastWheelRobotPosition = robotPosition
        self.lastWheelRobotYaw = yaw

        let localDelta = simd_quatf(angle: -yaw, axis: [0, 1, 0]).act(delta)
        let forwardDistance = -localDelta.x
        let lateralDistance = localDelta.z
        let rotationDistance = yawDelta * 0.18
        guard abs(forwardDistance) > 0.0001 || abs(lateralDistance) > 0.0001 || abs(rotationDistance) > 0.0001 else {
            return
        }

        let frontLeftWheelDelta = (forwardDistance + lateralDistance - rotationDistance) * wheelRadiansPerMeter
        let frontRightWheelDelta = (forwardDistance - lateralDistance + rotationDistance) * wheelRadiansPerMeter
        let backLeftWheelDelta = (forwardDistance - lateralDistance - rotationDistance) * wheelRadiansPerMeter
        let backRightWheelDelta = (forwardDistance + lateralDistance + rotationDistance) * wheelRadiansPerMeter

        frontLeftWheelSpin += frontLeftWheelDelta
        frontRightWheelSpin += frontRightWheelDelta
        backLeftWheelSpin += backLeftWheelDelta
        backRightWheelSpin += backRightWheelDelta

        frontLeftWheelEntity?.orientation = wheelOrientation(spin: frontLeftWheelSpin)
        backLeftWheelEntity?.orientation = wheelOrientation(spin: backLeftWheelSpin)
        frontRightWheelEntity?.orientation = wheelOrientation(spin: frontRightWheelSpin)
        backRightWheelEntity?.orientation = wheelOrientation(spin: backRightWheelSpin)
    }

    private func wheelOrientation(spin: Float) -> simd_quatf {
        simd_quatf(angle: spin, axis: playerModelPitchCorrection.act(wheelSpinAxis))
    }

    private func setPlayerVisibility(isVisible: Bool) {
        playerEntity.components.set(
            OpacityComponent(opacity: isVisible ? 1 : 0)
        )
    }
    
    
    
    
    
    private func addObstacles(from obstacles: [Obstacle]) {
        let canSpawnCoins = Date().timeIntervalSince(lastVisibleCoinSpawnDate) > 0.25
        var spawnedCoinCount = 0
        var didSpawnCoin = false

        for obstacle in obstacles {
            guard obstacleEntities[obstacle.id] == nil else {
                continue
            }

            switch obstacle.shape {
            case .box:
                do {
                    if obstacle.modelName == "Coin" {
                        guard canSpawnCoins,
                              spawnedCoinCount < 3,
                              isCoinVisibleEnoughToSpawn(obstacle) else {
                            continue
                        }
                    }

                    if shouldSkipCoinBecauseRealWorldIsOccupied(obstacle) {
                        continue
                    }

                    let collectibleEntity = try makeCollectibleEntity(named: obstacle.modelName)
                    collectibleEntity.name = obstacle.modelName
                    collectibleEntity.orientation = playerModelPitchCorrection

                    let bounds = collectibleEntity.visualBounds(relativeTo: collectibleEntity)
                    let basePosition = obstacle.position + SIMD3<Float>(0, -bounds.min.y, 0)

                    collectibleEntity.position = basePosition

                    collectibleEntity.components.set(
                        CollisionComponent(
                            shapes: [
                                .generateBox(size: obstacle.size)
                            ]
                        )
                    )

                    collectibleEntity.components.set(
                        PhysicsBodyComponent(mode: .static)
                    )

                    anchorEntity.addChild(collectibleEntity)
                    obstacleEntities[obstacle.id] = collectibleEntity
                    if obstacle.modelName == "Coin" {
                        spawnedCoinCount += 1
                        didSpawnCoin = true
                        startCoinRotationAnimation(for: collectibleEntity, delay: coinAnimationDelay(for: obstacle))
                    } else {
                        startFloatingAnimation(for: collectibleEntity, basePosition: basePosition)
                        startRotationAnimation(for: collectibleEntity)
                    }
                } catch {
                    print("Failed to load \(obstacle.modelName): \(error)")
                }
            }
        }

        if didSpawnCoin {
            lastVisibleCoinSpawnDate = Date()
        }
    }

    private func makeCollectibleEntity(named modelName: String) throws -> Entity {
        if let template = collectibleTemplates[modelName] {
            return template.clone(recursive: true)
        }

        let template = try Entity.load(named: modelName)
        collectibleTemplates[modelName] = template
        return template.clone(recursive: true)
    }

    private func shouldSkipCoinBecauseRealWorldIsOccupied(_ obstacle: Obstacle) -> Bool {
        guard obstacle.modelName == "Coin",
              let arView else {
            return false
        }

        let probeShape: ShapeResource
        if let coinObstacleProbeShape {
            probeShape = coinObstacleProbeShape
        } else {
            let generatedShape = ShapeResource.generateBox(size: SIMD3<Float>(0.18, 0.18, 0.18))
            coinObstacleProbeShape = generatedShape
            probeShape = generatedShape
        }

        let localStart = obstacle.position + SIMD3<Float>(0, 0.45, 0)
        let localEnd = obstacle.position + SIMD3<Float>(0, 0.12, 0)
        let worldStart = anchorEntity.convert(position: localStart, to: nil)
        let worldEnd = anchorEntity.convert(position: localEnd, to: nil)

        let hits = arView.scene.convexCast(
            convexShape: probeShape,
            fromPosition: worldStart,
            fromOrientation: simd_quatf(),
            toPosition: worldEnd,
            toOrientation: simd_quatf(),
            query: .nearest,
            mask: .sceneUnderstanding,
            relativeTo: nil
        )

        return hits.isEmpty == false
    }

    private func isCoinVisibleEnoughToSpawn(_ obstacle: Obstacle) -> Bool {
        guard obstacle.modelName == "Coin",
              let arView else {
            return true
        }

        let worldPosition = anchorEntity.convert(position: obstacle.position, to: nil)
        guard let screenPoint = arView.project(worldPosition) else {
            return false
        }

        return arView.bounds.insetBy(dx: -80, dy: -80).contains(screenPoint)
    }

    private func syncObstacles(from obstacles: [Obstacle]) {
        addObstacles(from: obstacles)

        let activeIDs = Set(obstacles.map(\.id))
        let removedIDs = obstacleEntities.keys.filter { activeIDs.contains($0) == false }

        for removedID in removedIDs {
            if let entity = obstacleEntities.removeValue(forKey: removedID) {
                if entity.name == "Coin" {
                    entity.removeFromParent()
                } else {
                    animateRemoval(of: entity)
                }
            }
        }
    }

    private func animateRemoval(of entity: Entity) {
        guard let parent = entity.parent else {
            return
        }

        entity.move(
            to: Transform(
                scale: SIMD3<Float>(repeating: 0.001),
                rotation: entity.orientation,
                translation: entity.position + SIMD3<Float>(0, 0.04, 0)
            ),
            relativeTo: parent,
            duration: 0.2,
            timingFunction: .easeIn
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            entity.removeFromParent()
        }
    }
    private func startFloatingAnimation(for entity: Entity, basePosition: SIMD3<Float>) {
        let upperPosition = basePosition + SIMD3<Float>(0, 0.01, 0)
        let lowerPosition = basePosition - SIMD3<Float>(0, 0.01, 0)

        func animateUp() {
            guard entity.parent != nil else {
                return
            }

            entity.move(
                to: Transform(scale: entity.scale, rotation: entity.orientation, translation: upperPosition),
                relativeTo: entity.parent,
                duration: 1.0,
                timingFunction: .easeInOut
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                animateDown()
            }
        }

        func animateDown() {
            guard entity.parent != nil else {
                return
            }

            entity.move(
                to: Transform(scale: entity.scale, rotation: entity.orientation, translation: lowerPosition),
                relativeTo: entity.parent,
                duration: 1.0,
                timingFunction: .easeInOut
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                animateUp()
            }
        }

        animateUp()
    }
    
    
    private func startRotationAnimation(for entity: Entity) {
        guard entity.parent != nil else {
            return
        }

        let fullRotation = simd_quatf(angle: -.pi * 2, axis: [0, 0, 1])
        let targetTransform = Transform(
            scale: entity.scale,
            rotation: fullRotation * entity.orientation,
            translation: entity.position
        )

        entity.move(
            to: targetTransform,
            relativeTo: entity.parent,
            duration: 12.0,
            timingFunction: .linear
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) {
            self.startRotationAnimation(for: entity)
        }
    }

    private func coinAnimationDelay(for obstacle: Obstacle) -> TimeInterval {
        let distanceOffset = max(0, abs(obstacle.position.z) - 0.65)
        return TimeInterval(distanceOffset * 1.25)
    }

    private func startCoinRotationAnimation(for entity: Entity, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let baseOrientation = entity.orientation
            let flippedOrientation = simd_quatf(angle: .pi, axis: [0, 1, 0]) * baseOrientation

            func rotate(to orientation: simd_quatf, then next: @escaping () -> Void) {
                guard entity.parent != nil else {
                    return
                }

                entity.move(
                    to: Transform(scale: entity.scale, rotation: orientation, translation: entity.position),
                    relativeTo: entity.parent,
                    duration: 7.0,
                    timingFunction: .easeInOut
                )

                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0, execute: next)
            }

            func rotateForward() {
                rotate(to: flippedOrientation, then: rotateBack)
            }

            func rotateBack() {
                rotate(to: baseOrientation, then: rotateForward)
            }

            rotateForward()
        }
    }
    
    
    func canMoveInRealWorld(from currentPosition: SIMD3<Float>, to candidatePosition: SIMD3<Float>, in arView: ARView) -> Bool {
        guard let realWorldCollisionShape else {
            return true
        }
        
        let heightOffset: Float = 0.08
        
        let localFromPosition = currentPosition + SIMD3<Float>(0, heightOffset, 0)
        let localToPosition = candidatePosition + SIMD3<Float>(0, heightOffset, 0)
        
        let worldFromPosition = anchorEntity.convert(position: localFromPosition, to: nil)
        let worldToPosition = anchorEntity.convert(position: localToPosition, to: nil)
        
        let hits = arView.scene.convexCast(
            convexShape: realWorldCollisionShape,
            fromPosition: worldFromPosition,
            fromOrientation: playerEntity.orientation,
            toPosition: worldToPosition,
            toOrientation: playerEntity.orientation,
            query: .nearest,
            mask: .sceneUnderstanding,
            relativeTo: nil
        )
        
        return hits.isEmpty
    }
}

final class SceneDebugController {
    private(set) var isDebugEnabled = false

    init() {}

    func configureSession(_ configuration: ARWorldTrackingConfiguration) {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
    }

    func updateDebugState(isEnabled: Bool, in arView: ARView) {
        guard isDebugEnabled != isEnabled else {
            return
        }

        isDebugEnabled = isEnabled

        if isEnabled {
            arView.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView.debugOptions.remove(.showSceneUnderstanding)
        }
    }
}
private extension Obstacle {
    var modelName: String {
        name
    }
}
