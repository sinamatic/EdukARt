//
//  CameraARView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//  CameraARView provides the RealityKit-based augmented reality environment
//  used during gameplay. It connects the SwiftUI game interface with an
//  ARKit world-tracking session and manages the virtual Eduard robot.
//
//  The Coordinator continuously receives AR frames and uses SwiftAprilTag
//  to detect AprilTags in the camera image. Detected tags are passed to
//  AprilTagLocalization, which estimates their poses and transforms them
//  into the ARKit world coordinate system. The resulting poses are forwarded
//  to AprilTagMapBuilder to construct the two-dimensional map.
//
//  The first successfully localized AprilTag is additionally used to place
//  and orient the virtual Eduard model in the AR environment. A fixed model
//  rotation offset aligns the coordinate system of the 3D model with the
//  AprilTag coordinate system.
//
//  Joystick input controls the virtual robot relative to its own orientation,
//  allowing forward and sideways movement to follow the robot's current
//  heading instead of the global AR coordinate axes.
//
//  Sources:
//  Apple ARKit:
//  https://developer.apple.com/documentation/arkit
//
//
//  RealityKit:
//  https://developer.apple.com/documentation/realitykit
//
//  SwiftAprilTag:
//  https://github.com/keyqcloud/SwiftAprilTag
//

// Technical Bridge to ARKit / RealityKit -> Street, Items, Obstacles, Eduard 3D 

import SwiftUI
import RealityKit
import ARKit
import Combine
import SwiftAprilTag
import SwiftUIJoystick
import UIKit


final class ARCoinRenderer {

    private var coinEntities:
        [UUID: Entity] = [:]

    private var basePositions:
        [UUID: SIMD3<Float>] = [:]

    private var phases:
        [UUID: Float] = [:]

    private var animationSubscription:
        Cancellable?

    private var elapsedTime:
        Float = 0

    private var hasPrintedHierarchyDebug =
        false


    func update(
        coins:
            [GameCoin],

        parent:
            Entity?,

        mapAnchor:
            Entity?,

        arView:
            ARView?
    ) {

        guard let parent
        else {
            return
        }

        let activeIDs =
            Set(
                coins.map {
                    $0.id
                }
            )

        for id in Array(
            coinEntities.keys
        )
        where activeIDs.contains(id) == false {

            coinEntities[id]?
                .removeFromParent()

            coinEntities[id] =
                nil

            basePositions[id] =
                nil

            phases[id] =
                nil
        }

        for coin in coins {

            guard coinEntities[
                coin.id
            ] == nil
            else {
                continue
            }

            do {

                let model =
                    try Entity.load(
                        named:
                            "Coin"
                    )

                let root =
                    Entity()

                root.name =
                    "ARCoin-\(coin.id)"

                root.position =
                    SIMD3<Float>(
                        coin.position.x,
                        0.10,
                        coin.position.y
                    )

                normalizeCoinSize(
                    model
                )

                correctCoinPivot(
                    model
                )

                root.addChild(
                    model
                )

                parent.addChild(
                    root
                )

                coinEntities[
                    coin.id
                ] =
                    root

                basePositions[
                    coin.id
                ] =
                    root.position

                phases[
                    coin.id
                ] =
                    Float.random(
                        in:
                            0...(.pi * 2)
                    )

            } catch {

                let mesh =
                    MeshResource.generateCylinder(
                        height:
                            0.008,

                        radius:
                            0.035
                    )

                let material =
                    SimpleMaterial(
                        color:
                            .yellow,

                        isMetallic:
                            true
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

                entity.name =
                    "ARCoin-\(coin.id)"

                entity.position =
                    SIMD3<Float>(
                        coin.position.x,
                        0.10,
                        coin.position.y
                    )

                parent.addChild(
                    entity
                )

                coinEntities[
                    coin.id
                ] =
                    entity

                basePositions[
                    coin.id
                ] =
                    entity.position

                phases[
                    coin.id
                ] =
                    Float.random(
                        in:
                            0...(.pi * 2)
                    )
            }
        }

        updateAnimation(
            arView:
                arView
        )

        printHierarchyDebugIfNeeded(
            mapAnchor:
                mapAnchor,

            mapRoot:
                parent
        )
    }


    func clear() {

        for entity in coinEntities.values {

            entity.removeFromParent()
        }

        coinEntities
            .removeAll()

        basePositions
            .removeAll()

        phases
            .removeAll()

        animationSubscription?
            .cancel()

        animationSubscription =
            nil

        hasPrintedHierarchyDebug =
            false
    }


    private func normalizeCoinSize(
        _ entity:
            Entity
    ) {

        let bounds =
            entity.visualBounds(
                relativeTo:
                    nil
            )

        let width =
            max(
                bounds.extents.x,
                bounds.extents.z
            )

        guard width > 0
        else {
            return
        }

        entity.scale *=
            SIMD3<Float>(
                repeating:
                    0.07 / width
            )
    }


    private func correctCoinPivot(
        _ entity:
            Entity
    ) {

        let bounds =
            entity.visualBounds(
                relativeTo:
                    entity
            )

        entity.position.y -=
            bounds.center.y
    }


    private func printHierarchyDebugIfNeeded(
        mapAnchor:
            Entity?,

        mapRoot:
            Entity
    ) {

        guard hasPrintedHierarchyDebug == false,
              let firstCoin =
                coinEntities.values.first
        else {
            return
        }

        hasPrintedHierarchyDebug =
            true

        print(
            "# COIN HIERARCHY | mapAnchor y:",
            mapAnchor?.position.y ?? 0,
            "| mapRoot y:",
            mapRoot.position.y,
            "| first coinRoot y:",
            firstCoin.position.y
        )
    }


    private func updateAnimation(
        arView:
            ARView?
    ) {

        guard coinEntities.isEmpty == false,
              animationSubscription == nil,
              let arView
        else {
            return
        }

        animationSubscription =
            arView.scene.subscribe(
                to:
                    SceneEvents.Update.self
            ) { [weak self] event in

                guard let self
                else {
                    return
                }

                self.elapsedTime +=
                    Float(
                        event.deltaTime
                    )

                for (
                    id,
                    entity
                ) in self.coinEntities {

                    guard let basePosition =
                        self.basePositions[
                            id
                        ]
                    else {
                        continue
                    }

                    let phase =
                        self.phases[
                            id
                        ]
                        ?? 0

                    entity.position =
                        basePosition
                        +
                        SIMD3<Float>(
                            0,
                            sin(
                                self.elapsedTime * 2
                                +
                                phase
                            )
                            * 0.015,
                            0
                        )

                    entity.orientation =
                        simd_quatf(
                            angle:
                                self.elapsedTime * 2.5
                                +
                                phase,

                            axis:
                                SIMD3<Float>(
                                    0,
                                    1,
                                    0
                                )
                        )
                }

                if self.coinEntities.isEmpty {

                    self.animationSubscription?
                        .cancel()

                    self.animationSubscription =
                        nil
                }
            }
    }
}


struct CameraARView: UIViewRepresentable {

    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var joystickMonitor: JoystickMonitor
    @ObservedObject var turnJoystickMonitor: JoystickMonitor

    @ObservedObject var mapBuilder: AprilTagMapBuilder
    @ObservedObject var controller:
        RobotController
    @ObservedObject var gameController:
        GameController
    let gameMap:
        GameMap?
    let localizationResetID:
        Int
    let requiredReferenceTagID:
        Int
    let onReferenceTagLocalized:
        () -> Void
    let onRobotPoseUpdated:
        (RobotPose) -> Void
    let onRobotPoseLost:
        () -> Void

    init(
        eduardModelStore: EduardModelStore,
        joystickMonitor: JoystickMonitor,
        turnJoystickMonitor: JoystickMonitor,
        mapBuilder: AprilTagMapBuilder,
        controller: RobotController,
        gameController: GameController,
        gameMap: GameMap? = nil,
        localizationResetID: Int = 0,
        requiredReferenceTagID: Int = 0,
        onReferenceTagLocalized: @escaping () -> Void = {},
        onRobotPoseUpdated: @escaping (RobotPose) -> Void = { _ in },
        onRobotPoseLost: @escaping () -> Void = {}
    ) {

        self.eduardModelStore =
            eduardModelStore

        self.joystickMonitor =
            joystickMonitor

        self.turnJoystickMonitor =
            turnJoystickMonitor

        self.mapBuilder =
            mapBuilder

        self.controller =
            controller

        self.gameController =
            gameController

        self.gameMap =
            gameMap

        self.localizationResetID =
            localizationResetID

        self.requiredReferenceTagID =
            requiredReferenceTagID

        self.onReferenceTagLocalized =
            onReferenceTagLocalized

        self.onRobotPoseUpdated =
            onRobotPoseUpdated

        self.onRobotPoseLost =
            onRobotPoseLost
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {

        Coordinator(
            mapBuilder:
                mapBuilder,

            controller:
                controller,

            gameMap:
                gameMap,

            requiredReferenceTagID:
                requiredReferenceTagID,

            onReferenceTagLocalized:
                onReferenceTagLocalized,

            onRobotPoseUpdated:
                onRobotPoseUpdated,

            onRobotPoseLost:
                onRobotPoseLost
        )
    }


    // MARK: - Create ARView

    func makeUIView(
        context: Context
    ) -> ARView {

        PerformanceLogger.shared.start(
            "Create ARView"
        )


        // --------------------------------------------------
        // Create ARView
        // --------------------------------------------------

        let arView = ARView(
            frame: .zero,
            cameraMode: .ar,
            automaticallyConfigureSession: false
        )

        context.coordinator.arView =
            arView


        // --------------------------------------------------
        // ARSession Delegate
        // --------------------------------------------------

        arView.session.delegate =
            context.coordinator

        arView.session.delegateQueue =
            DispatchQueue(
                label: "AprilTagDetectionQueue",
                qos: .userInitiated
            )


        PerformanceLogger.shared.end(
            "Create ARView"
        )


        // --------------------------------------------------
        // RealityKit Statistics
        // --------------------------------------------------
//
//        arView.debugOptions.insert(
//            .showStatistics
//        )


        // --------------------------------------------------
        // ARKit World Tracking
        // --------------------------------------------------
        //
        // No plane detection is required.
        //
        // ARKit is used to continuously track the
        // iPhone pose in the world coordinate system.
        // --------------------------------------------------

        let configuration =
            ARWorldTrackingConfiguration()


        PerformanceLogger.shared.start(
            "Start ARSession"
        )

        arView.session.run(
            configuration
        )

        PerformanceLogger.shared.end(
            "Start ARSession"
        )


        // --------------------------------------------------
        // Map Anchor
        // --------------------------------------------------

        let mapAnchor =
            AnchorEntity(
                world: .zero
            )

        arView.scene.addAnchor(
            mapAnchor
        )

        context.coordinator.mapAnchor =
            mapAnchor


        // --------------------------------------------------
        // Load preloaded Eduard
        // --------------------------------------------------

        if let model =
            eduardModelStore.model {

            let simulationRoot =
                Entity()


            let eduard =
                model.clone(
                    recursive: true
                )


            let visualCorrectionRoot =
                Entity()

            visualCorrectionRoot.addChild(
                eduard
            )

            simulationRoot.addChild(
                visualCorrectionRoot
            )

            alignVisualRootToGround(
                visualCorrectionRoot,
                    relativeTo:
                        simulationRoot
            )
            
            context.coordinator.simulationRoot =
                simulationRoot

            context.coordinator.eduard =
                eduard

            controller.eduardSimulation.show(
                entity:
                    simulationRoot
            )

            if let occlusionRoot =
                makeEduardOcclusionRoot() {

                context.coordinator.occlusionRoot =
                    occlusionRoot

                controller.eduardOccluder.show(
                    entity:
                        occlusionRoot
                )

            } else {

                print(
                    "# EDUARD OCCLUDER LOAD FAILED | eduard_occlusion"
                )
            }

            controller.eduardSimulation.setVisible(
                controller.isSimulationVisible
            )

            print(
                "# Used preloaded Eduard model"
            )

        } else {

            print(
                "# Eduard model is not loaded yet"
            )
        }

        return arView
    }


    private func makeEduardOcclusionRoot() -> Entity? {
        guard let model =
            try? Entity.load(
                named:
                    "eduard_occlusion"
            )
        else {
            return nil
        }

        let root =
            Entity()

        let visualCorrectionRoot =
            Entity()

        visualCorrectionRoot.orientation =
            simd_quatf(
                angle:
                    .pi,
                axis:
                    SIMD3<Float>(
                        0,
                        1,
                        0
                    )
            )

        visualCorrectionRoot.addChild(
            model
        )

        root.addChild(
            visualCorrectionRoot
        )

        alignVisualRootToGround(
            visualCorrectionRoot,
            relativeTo:
                root
        )
        return root
    }

    // MARK: - Align Eduard to Ground
    private func alignModelBottomToGround(
        _ model: Entity,
        relativeTo parent: Entity
    ) {
        let bounds =
            model.visualBounds(
                relativeTo:
                    parent
            )

        model.position.y -=
        bounds.min.y - 0.13 // offset so occlusion lies on floor not on robot

        print(
            "# MODEL GROUND ALIGN | minY:",
            bounds.min.y,
            "| correction:",
            -bounds.min.y
        )
    }
    
    // MARK: - Occluder Position
    
    private func alignVisualRootToGround(
        _ visualRoot: Entity,
        relativeTo root: Entity
    ) {
        let bounds =
            visualRoot.visualBounds(
                relativeTo:
                    root
            )

        visualRoot.position.y -=
            bounds.min.y

        let correctedBounds =
            visualRoot.visualBounds(
                relativeTo:
                    root
            )

        print(
            "# GROUND ALIGN | before:",
            bounds.min.y,
            "| after:",
            correctedBounds.min.y
        )
    }

    

    // MARK: - Update ARView

    func updateUIView(
        _ uiView: ARView,
        context: Context
    ) {

        if context.coordinator.lastLocalizationResetID
            != localizationResetID {

            context.coordinator
                .aprilTagLocalization
                .reset()

            context.coordinator
                .resetMultiTagLocalization()


            if context.coordinator.requiredReferenceTagID > 0 {

                context.coordinator
                    .aprilTagLocalization
                    .setReferenceTag(
                        id:
                            context.coordinator
                                .requiredReferenceTagID
                    )
            }


            context.coordinator
                .lastLocalizationResetID =
                localizationResetID

            context.coordinator
                .hasRenderedTrack =
                false

            context.coordinator
                .hasRenderedMapObjects =
                false

            context.coordinator
                .mapObjectAnimationSubscription?
                .cancel()

            context.coordinator
                .mapObjectAnimationSubscription =
                nil

            context.coordinator
                .animatedMapObjects
                .removeAll()

            context.coordinator
                .clearRuntimeGameARContent()
        }

        context.coordinator
            .updateRuntimeMapObjects(
                gameController
                    .activeMapObjects
            )

        context.coordinator
            .updateShitDots(
                gameController
                    .shitDots
            )

        context.coordinator
            .updateCoins(
                gameController
                    .coins
            )

        context.coordinator
            .updateEggs(
                gameController
                    .runtimeEggs,

                robotPose:
                    gameController
                        .latestRobotPose
            )
    }
    
    




    // ======================================================
    // MARK: - Coordinator
    // ======================================================

    final class Coordinator:
        NSObject,
        ARSessionDelegate
    {

        weak var arView: ARView?
        var mapAnchor: AnchorEntity?
        var mapRoot: Entity?

        // ======================================================
        // MARK: - Multi-Tag Map Stabilization
        // ======================================================

        /// Current best estimate of the complete
        /// map coordinate system in ARKit world space.
        private var stabilizedMapWorldTransform:
            simd_float4x4?


        /// We only correct the map occasionally.
        private var lastMapStabilization =
            Date.distantPast


        /// Maximum frequency of multi-tag map correction.
        private let mapStabilizationInterval:
            TimeInterval = 0.75


        /// Require at least two known map tags.
        private let minimumStabilizationTagCount =
            2


        /// Small corrections are interpolated instead of
        /// instantly moving the complete map.
        private let mapStabilizationFactor:
            Float = 0.05


        /// Ignore obviously implausible jumps.
        private let maximumMapCorrectionDistance:
            Float = 0.25

        var simulationRoot: Entity?
        var occlusionRoot: Entity?
        var eduard: Entity?
        private let trackRenderer =
            ARTrackRenderer()
        var hasRenderedTrack =
            false
        var hasRenderedMapObjects =
            false
        var mapObjectAnimationSubscription:
            Cancellable?
        var mapObjectAnimationTime:
            Float = 0
        var animatedMapObjects:
            [AnimatedMapObject] = []

        private struct VisibleMapTag {

            let stored:
                StoredAprilTag

            let worldTransform:
                simd_float4x4
        }

        // MARK: - Runtime Game AR Content

        var mapObjectEntities:
            [UUID: Entity] = [:]

        var shitDotEntities:
            [UUID: Entity] = [:]

        let coinRenderer =
            ARCoinRenderer()

        let eggRenderer =
            AREggRenderer()

        var lastLocalizationResetID:
            Int = 0
        
        // --------------------------------------------------
        // AR objects placed on AprilTags
        // --------------------------------------------------
        //
        // Stores one RealityKit anchor per AprilTag.
        // This prevents creating a new cube every time
        // the same tag is detected again.
        // --------------------------------------------------

        var aprilTagAnchors:
            [Int: AnchorEntity] = [:]
        
        // --------------------------------------------------
        // AprilTag Map Builder
        // --------------------------------------------------
        let mapBuilder: AprilTagMapBuilder
        let controller:
            RobotController
        let gameMap:
            GameMap?
        let requiredReferenceTagID:
            Int
        let onReferenceTagLocalized:
            () -> Void
        let onRobotPoseUpdated:
            (RobotPose) -> Void
        let onRobotPoseLost:
            () -> Void

        private var lastRobotPoseUpdate =
            Date.distantPast

        private let robotPoseTimeout:
            TimeInterval = 0.75

        init(
            mapBuilder: AprilTagMapBuilder,
            controller: RobotController,
            gameMap: GameMap?,
            requiredReferenceTagID: Int,
            onReferenceTagLocalized: @escaping () -> Void,
            onRobotPoseUpdated: @escaping (RobotPose) -> Void,
            onRobotPoseLost: @escaping () -> Void
        ) {

            self.mapBuilder =
                mapBuilder

            self.controller =
                controller

            self.gameMap =
                gameMap

            self.requiredReferenceTagID =
                requiredReferenceTagID

            self.onReferenceTagLocalized =
                onReferenceTagLocalized

            self.onRobotPoseUpdated =
                onRobotPoseUpdated

            self.onRobotPoseLost =
                onRobotPoseLost


            super.init()


            if requiredReferenceTagID > 0 {

                aprilTagLocalization
                    .setReferenceTag(
                        id:
                            requiredReferenceTagID
                    )
            }
        }


        struct AnimatedMapObject {

            let entity:
                Entity

            let basePosition:
                SIMD3<Float>

            let baseOrientation:
                simd_quatf

            let phase:
                Float
        }

        // --------------------------------------------------
        // AprilTag Detector
        // --------------------------------------------------

        let detector =
            try! Detector(
                families: [
                    .tag36h11
                ]
            )


        // --------------------------------------------------
        // AprilTag Localization
        // --------------------------------------------------
        //
        // Tag 0 defines the origin and orientation
        // of the EdukARt 2D map.
        //
        // 96 mm = measured black AprilTag square.
        // --------------------------------------------------

        let aprilTagLocalization =
            AprilTagLocalization(
                tagSize: 0.096
            )


        // --------------------------------------------------
        // Detection Control
        // --------------------------------------------------

        var isDetecting =
            false

        var frameCounter =
            0



        // ==================================================
        // MARK: - ARSession Frames
        // ==================================================

        func session(
            _ session: ARSession,
            didUpdate frame: ARFrame
        ) {

            // --------------------------------------------------
            // Only analyse every sixth ARFrame
            // --------------------------------------------------

            frameCounter += 1

            guard frameCounter % 6 == 0
            else {
                return
            }


            // --------------------------------------------------
            // Prevent simultaneous AprilTag detections
            // --------------------------------------------------

            guard isDetecting == false
            else {
                return
            }

            isDetecting =
                true

            defer {

                isDetecting =
                    false
            }


            // --------------------------------------------------
            // Camera image
            // --------------------------------------------------

            let pixelBuffer =
                frame.capturedImage


            do {

                // ----------------------------------------------
                // Detect ALL visible AprilTags
                // ----------------------------------------------

                let detections =
                    try detector.detect(
                        pixelBuffer:
                            pixelBuffer
                    )


                // ----------------------------------------------
                // Camera Intrinsics
                // ----------------------------------------------

                let cameraMatrix =
                    frame.camera.intrinsics


                let intrinsics =
                    CameraIntrinsics(

                        fx: Double(
                            cameraMatrix
                                .columns.0.x
                        ),

                        fy: Double(
                            cameraMatrix
                                .columns.1.y
                        ),

                        cx: Double(
                            cameraMatrix
                                .columns.2.x
                        ),

                        cy: Double(
                            cameraMatrix
                                .columns.2.y
                        )
                    )


                // --------------------------------------------------
                // Select reference tag
                // --------------------------------------------------

                if requiredReferenceTagID > 0 {

                    aprilTagLocalization
                        .setReferenceTag(
                            id:
                                requiredReferenceTagID
                        )

                } else {

                    aprilTagLocalization.selectReferenceTag(
                        from:
                            detections
                    )
                }
                
                // --------------------------------------------------
                // Give reference ID to map builder
                // --------------------------------------------------

                
                if let referenceID =
                    aprilTagLocalization.referenceTagID {

                    DispatchQueue.main.async {

                        self.mapBuilder.setReferenceTag(
                            id: referenceID
                        )
                    }
                }
                
                // ======================================================
                // Localize visible AprilTags
                // ======================================================

                var didUpdateRobotPose =
                    false


                var visibleMapTags:
                    [VisibleMapTag] = []


                // Keep robot detection for a moment.
                // We localize it AFTER map stabilization.
                var robotDetection:
                    Detection?


                for detection in detections {


                    // --------------------------------------------------
                    // Robot tag #0
                    // --------------------------------------------------

                    if detection.id == 0 {

                        robotDetection =
                            detection

                        continue
                    }


                    // --------------------------------------------------
                    // Map tags
                    // --------------------------------------------------

                    guard let mapPose =
                        aprilTagLocalization.localize(
                            detection:
                                detection,

                            frame:
                                frame,

                            intrinsics:
                                intrinsics
                        )
                    else {
                        continue
                    }


                    // --------------------------------------------------
                    // Initial localization through reference tag
                    // --------------------------------------------------

                    if detection.id
                        == requiredReferenceTagID {

                        if let mapReferenceWorldTransform =
                            aprilTagLocalization
                                .mapReferenceWorldTransform {

                            let mapRootTransform =
                                makeMapRootTransform(
                                    from:
                                        mapReferenceWorldTransform
                                )


                            // Use initial reference as first
                            // stabilized map estimate.
                            if stabilizedMapWorldTransform
                                == nil {

                                stabilizedMapWorldTransform =
                                    mapRootTransform

                                DispatchQueue.main.async {

                                    self.localizeMapAnchor(
                                        with:
                                            mapRootTransform
                                    )
                                }
                            }
                        }

                        DispatchQueue.main.async {

                            self
                                .onReferenceTagLocalized()
                        }
                    }


                    // --------------------------------------------------
                    // Map Builder
                    // --------------------------------------------------

                    DispatchQueue.main.async {

                        self.mapBuilder.add(
                            pose:
                                mapPose
                        )
                    }


                    // --------------------------------------------------
                    // Is this tag part of the SAVED game map?
                    // --------------------------------------------------

                    if let storedTag =
                        gameMap?
                            .aprilTags
                            .first(
                                where: {
                                    $0.id
                                        == detection.id
                                }
                            ) {

                        visibleMapTags.append(
                            VisibleMapTag(
                                stored:
                                    storedTag,

                                worldTransform:
                                    mapPose.worldTransform
                            )
                        )
                    }


                    // ----------------------------------------------
                    // Debug output
                    // ----------------------------------------------

                    print(
                        String(
                            format:
                                "# ID %d | X %+7.3f | Z %+7.3f | Rotation %+7.2f° | Height %+7.3f",
                            mapPose.id,
                            mapPose.x,
                            mapPose.z,
                            mapPose.rotation
                                * 180
                                / .pi,
                            mapPose.height
                        )
                    )
                }


                // ======================================================
                // Multi-Tag map stabilization
                // ======================================================
                if gameMap != nil {

                    stabilizeMap(
                        using:
                            visibleMapTags
                    )
                }


                // ======================================================
                // Robot localization
                // ======================================================

                if let robotDetection {

                    if let robotPose =
                        aprilTagLocalization.localizeRobot(
                            detection:
                                robotDetection,

                            frame:
                                frame,

                            intrinsics:
                                intrinsics,

                            mapWorldTransform:
                                stabilizedMapWorldTransform
                        ) {

                        didUpdateRobotPose =
                            true

                        lastRobotPoseUpdate =
                            Date()


                        DispatchQueue.main.async {

                            self.controller
                                .eduardOccluder
                                .setEnabled(
                                    true
                                )


                            self.onRobotPoseUpdated(
                                robotPose
                            )
                        }
                    }
                }

                if didUpdateRobotPose == false {

                    let timeSinceLastPose =
                        Date()
                            .timeIntervalSince(
                                lastRobotPoseUpdate
                            )

                    if timeSinceLastPose
                        > robotPoseTimeout {

                        DispatchQueue.main.async {

                            self.onRobotPoseLost()
                        }
                    }
                }

            } catch {

                print(
                    "# AprilTag detection error:",
                    error
                )
            }
        }


        // MARK: - Stable Map Transform

        private func makeMapRootTransform(
            from transform: simd_float4x4
        ) -> simd_float4x4 {

            // Position of the detected reference AprilTag.
            let position =
                SIMD3<Float>(
                    transform.columns.3.x,
                    transform.columns.3.y,
                    transform.columns.3.z
                )


            // Take the tag's X direction,
            // but project it onto ARKit's horizontal X/Z plane.
            var xAxis =
                SIMD3<Float>(
                    transform.columns.0.x,
                    0,
                    transform.columns.0.z
                )


            guard simd_length(xAxis) > 0.001
            else {
                return transform
            }


            xAxis =
                simd_normalize(
                    xAxis
                )


            // ARKit Y is the vertical direction.
            let yAxis =
                SIMD3<Float>(
                    0,
                    1,
                    0
                )


            // Build the matching horizontal Z axis.
            let zAxis =
                simd_normalize(
                    simd_cross(
                        xAxis,
                        yAxis
                    )
                )


            return simd_float4x4(
                columns: (

                    SIMD4<Float>(
                        xAxis.x,
                        xAxis.y,
                        xAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        yAxis.x,
                        yAxis.y,
                        yAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        zAxis.x,
                        zAxis.y,
                        zAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        position.x,
                        position.y,
                        position.z,
                        1
                    )
                )
            )
        }


        // MARK: - Stored AprilTag Transform

        private func makeStoredTagTransform(
            _ tag: StoredAprilTag
        ) -> simd_float4x4 {

            // Stored rotation describes the tag's X axis
            // inside the 2D map.
            let xAxis =
                SIMD3<Float>(
                    cos(tag.rotation),
                    0,
                    sin(tag.rotation)
                )


            let yAxis =
                SIMD3<Float>(
                    0,
                    1,
                    0
                )


            let zAxis =
                simd_normalize(
                    simd_cross(
                        xAxis,
                        yAxis
                    )
                )


            return simd_float4x4(
                columns: (

                    SIMD4<Float>(
                        xAxis.x,
                        xAxis.y,
                        xAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        yAxis.x,
                        yAxis.y,
                        yAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        zAxis.x,
                        zAxis.y,
                        zAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        tag.x,
                        0,
                        tag.z,
                        1
                    )
                )
            )
        }


        // MARK: - Map Transform Candidate

        private func mapTransformCandidate(
            from visibleTag:
                VisibleMapTag
        ) -> simd_float4x4 {

            // --------------------------------------------------
            // Stored pose of this AprilTag inside the saved map
            // --------------------------------------------------

            let storedTagTransform =
                makeStoredTagTransform(
                    visibleTag.stored
                )


            // --------------------------------------------------
            // Currently measured pose of the same AprilTag
            // in ARKit world space
            // --------------------------------------------------
            //
            // Flatten the tag onto the horizontal plane so
            // small measured floor tilts do not tilt the map.
            // --------------------------------------------------

            let measuredTagTransform =
                makeMapRootTransform(
                    from:
                        visibleTag.worldTransform
                )


            // --------------------------------------------------
            // Calculate map -> ARKit world transform
            // --------------------------------------------------
            //
            // measuredTagWorld
            // =
            // mapWorld * storedTagMap
            //
            // therefore:
            //
            // mapWorld
            // =
            // measuredTagWorld
            // * inverse(storedTagMap)
            // --------------------------------------------------

            return measuredTagTransform
                * simd_inverse(
                    storedTagTransform
                )
        }


        // MARK: - Average Map Transforms

        private func averageMapTransforms(
            _ transforms: [simd_float4x4]
        ) -> simd_float4x4? {

            guard transforms.isEmpty == false else {
                return nil
            }


            // --------------------------------------------------
            // Average position
            // --------------------------------------------------

            var positionSum =
                SIMD3<Float>.zero


            // --------------------------------------------------
            // Average horizontal rotation
            // --------------------------------------------------

            var sineSum:
                Float = 0

            var cosineSum:
                Float = 0


            for transform in transforms {

                positionSum +=
                    SIMD3<Float>(
                        transform.columns.3.x,
                        transform.columns.3.y,
                        transform.columns.3.z
                    )


                let xAxis =
                    transform.columns.0

                let yaw =
                    atan2(
                        xAxis.z,
                        xAxis.x
                    )


                sineSum +=
                    sin(yaw)

                cosineSum +=
                    cos(yaw)
            }


            let count =
                Float(
                    transforms.count
                )


            let position =
                positionSum
                / count


            let yaw =
                atan2(
                    sineSum,
                    cosineSum
                )


            // --------------------------------------------------
            // Build clean horizontal map transform
            // --------------------------------------------------

            let xAxis =
                SIMD3<Float>(
                    cos(yaw),
                    0,
                    sin(yaw)
                )


            let yAxis =
                SIMD3<Float>(
                    0,
                    1,
                    0
                )


            let zAxis =
                simd_normalize(
                    simd_cross(
                        xAxis,
                        yAxis
                    )
                )


            return simd_float4x4(
                columns: (

                    SIMD4<Float>(
                        xAxis.x,
                        xAxis.y,
                        xAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        yAxis.x,
                        yAxis.y,
                        yAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        zAxis.x,
                        zAxis.y,
                        zAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        position.x,
                        position.y,
                        position.z,
                        1
                    )
                )
            )
        }


        // MARK: - Interpolate Map Transform

        private func interpolateMapTransform(
            from current:
                simd_float4x4,

            to target:
                simd_float4x4,

            factor:
                Float
        ) -> simd_float4x4 {


            // --------------------------------------------------
            // Position
            // --------------------------------------------------

            let currentPosition =
                SIMD3<Float>(
                    current.columns.3.x,
                    current.columns.3.y,
                    current.columns.3.z
                )

            let targetPosition =
                SIMD3<Float>(
                    target.columns.3.x,
                    target.columns.3.y,
                    target.columns.3.z
                )


            let position =
                simd_mix(
                    currentPosition,
                    targetPosition,
                    SIMD3<Float>(
                        repeating:
                            factor
                    )
                )


            // --------------------------------------------------
            // Rotation
            // --------------------------------------------------

            let currentYaw =
                atan2(
                    current.columns.0.z,
                    current.columns.0.x
                )

            let targetYaw =
                atan2(
                    target.columns.0.z,
                    target.columns.0.x
                )


            let currentRotation =
                simd_quatf(
                    angle:
                        currentYaw,

                    axis:
                        SIMD3<Float>(
                            0,
                            1,
                            0
                        )
                )


            let targetRotation =
                simd_quatf(
                    angle:
                        targetYaw,

                    axis:
                        SIMD3<Float>(
                            0,
                            1,
                            0
                        )
                )


            let rotation =
                simd_slerp(
                    currentRotation,
                    targetRotation,
                    factor
                )


            var transform =
                simd_float4x4(
                    rotation
                )


            transform.columns.3 =
                SIMD4<Float>(
                    position.x,
                    position.y,
                    position.z,
                    1
                )


            return transform
        }


        // MARK: - Stabilize Map

        private func stabilizeMap(
            using visibleTags:
                [VisibleMapTag]
        ) {

            // --------------------------------------------------
            // Only occasionally
            // --------------------------------------------------

            guard Date()
                .timeIntervalSince(
                    lastMapStabilization
                )
                >= mapStabilizationInterval
            else {
                return
            }


            // --------------------------------------------------
            // At least two known tags
            // --------------------------------------------------

            guard visibleTags.count
                    >= minimumStabilizationTagCount
            else {
                return
            }


            // --------------------------------------------------
            // Initial localization must already exist
            // --------------------------------------------------

            guard let currentTransform =
                stabilizedMapWorldTransform
            else {
                return
            }


            lastMapStabilization =
                Date()


            // --------------------------------------------------
            // Estimate complete map pose from tag CENTERS.
            // --------------------------------------------------

            guard let measuredTransform =
                estimateMapTransform(
                    from:
                        visibleTags,

                    currentTransform:
                        currentTransform
                )
            else {
                return
            }


            // --------------------------------------------------
            // Current / measured positions
            // --------------------------------------------------

            let currentPosition =
                SIMD3<Float>(
                    currentTransform.columns.3.x,
                    currentTransform.columns.3.y,
                    currentTransform.columns.3.z
                )


            let measuredPosition =
                SIMD3<Float>(
                    measuredTransform.columns.3.x,
                    measuredTransform.columns.3.y,
                    measuredTransform.columns.3.z
                )


            let correctionDistance =
                simd_distance(
                    currentPosition,
                    measuredPosition
                )


            // --------------------------------------------------
            // Rotation difference
            // --------------------------------------------------

            let currentYaw =
                atan2(
                    currentTransform.columns.0.z,
                    currentTransform.columns.0.x
                )


            let measuredYaw =
                atan2(
                    measuredTransform.columns.0.z,
                    measuredTransform.columns.0.x
                )


            let rawYawDifference =
                measuredYaw
                - currentYaw


            // Normalize to -π ... +π.
            let yawDifference =
                atan2(
                    sin(rawYawDifference),
                    cos(rawYawDifference)
                )


            // --------------------------------------------------
            // Reject obviously bad measurements
            // --------------------------------------------------

            guard correctionDistance
                    <= maximumMapCorrectionDistance
            else {

                print(
                    String(
                        format:
                            "# MAP CORRECTION REJECTED | %.3f m",
                        correctionDistance
                    )
                )

                return
            }


            // Also reject unreasonable rotation jumps.
            let maximumYawCorrection =
                Float(
                    15.0 * .pi / 180.0
                )


            guard abs(yawDifference)
                    <= maximumYawCorrection
            else {

                print(
                    String(
                        format:
                            "# MAP ROTATION REJECTED | %.2f°",
                        yawDifference
                            * 180
                            / .pi
                    )
                )

                return
            }


            // --------------------------------------------------
            // Smooth correction
            // --------------------------------------------------

            let correctedTransform =
                interpolateMapTransform(
                    from:
                        currentTransform,

                    to:
                        measuredTransform,

                    factor:
                        mapStabilizationFactor
                )


            stabilizedMapWorldTransform =
                correctedTransform


            // RealityKit mutation belongs on Main.
            DispatchQueue.main.async {

                self.localizeMapAnchor(
                    with:
                        correctedTransform
                )
            }


            print(
                String(
                    format:
                        "# MAP STABILIZED | %d tags | pos %.3f m | rot %.2f°",
                    visibleTags.count,
                    correctionDistance,
                    yawDifference
                        * 180
                        / .pi
                )
            )
        }
        
        // MARK: - Estimate Map Transform From Tag Positions

        private func estimateMapTransform(
            from visibleTags:
                [VisibleMapTag],

            currentTransform:
                simd_float4x4
        ) -> simd_float4x4? {

            // At least two different tag positions are required
            // to determine both position and rotation.
            guard visibleTags.count >= 2
            else {
                return nil
            }
            
            // --------------------------------------------------
            // The visible tag constellation must span enough space.
            // --------------------------------------------------
            //
            // Two tags that are almost next to each other provide
            // a poor estimate of map rotation.
            // --------------------------------------------------

            var maximumStoredDistance:
                Float = 0


            for firstIndex in
                visibleTags.indices {

                for secondIndex in
                    visibleTags.indices
                where secondIndex > firstIndex {

                    let first =
                        SIMD2<Float>(
                            visibleTags[firstIndex].stored.x,
                            visibleTags[firstIndex].stored.z
                        )

                    let second =
                        SIMD2<Float>(
                            visibleTags[secondIndex].stored.x,
                            visibleTags[secondIndex].stored.z
                        )


                    maximumStoredDistance =
                        max(
                            maximumStoredDistance,

                            simd_distance(
                                first,
                                second
                            )
                        )
                }
            }


            guard maximumStoredDistance
                    >= 0.50
            else {

                print(
                    "# MAP STABILIZATION SKIPPED | tags too close"
                )

                return nil
            }
            

            // --------------------------------------------------
            // Calculate centroids
            // --------------------------------------------------

            var storedCentroid =
                SIMD2<Float>.zero

            var observedCentroid =
                SIMD2<Float>.zero


            for tag in visibleTags {

                storedCentroid +=
                    SIMD2<Float>(
                        tag.stored.x,
                        tag.stored.z
                    )

                observedCentroid +=
                    SIMD2<Float>(
                        tag.worldTransform.columns.3.x,
                        tag.worldTransform.columns.3.z
                    )
            }


            let count =
                Float(
                    visibleTags.count
                )


            storedCentroid /=
                count

            observedCentroid /=
                count


            // --------------------------------------------------
            // Find best horizontal rotation
            // --------------------------------------------------
            //
            // We align the STORED tag positions with the
            // currently OBSERVED ARKit world positions.
            //
            // Important:
            // Individual AprilTag rotations are NOT used.
            // Only the centers of the tags matter.
            // --------------------------------------------------

            var dotSum:
                Float = 0

            var crossSum:
                Float = 0


            for tag in visibleTags {

                let stored =
                    SIMD2<Float>(
                        tag.stored.x,
                        tag.stored.z
                    )
                    - storedCentroid


                let observed =
                    SIMD2<Float>(
                        tag.worldTransform.columns.3.x,
                        tag.worldTransform.columns.3.z
                    )
                    - observedCentroid


                dotSum +=
                    stored.x * observed.x
                    +
                    stored.y * observed.y


                crossSum +=
                    stored.x * observed.y
                    -
                    stored.y * observed.x
            }


            guard abs(dotSum) + abs(crossSum)
                    > 0.0001
            else {
                return nil
            }


            let yaw =
                atan2(
                    crossSum,
                    dotSum
                )


            let cosYaw =
                cos(yaw)

            let sinYaw =
                sin(yaw)


            // --------------------------------------------------
            // Rotate stored centroid into ARKit world orientation
            // --------------------------------------------------

            let rotatedStoredCentroid =
                SIMD2<Float>(
                    cosYaw * storedCentroid.x
                        - sinYaw * storedCentroid.y,

                    sinYaw * storedCentroid.x
                        + cosYaw * storedCentroid.y
                )


            // --------------------------------------------------
            // Translation of complete map
            // --------------------------------------------------

            let translation =
                observedCentroid
                - rotatedStoredCentroid


            // --------------------------------------------------
            // Build horizontal map transform
            // --------------------------------------------------

            let xAxis =
                SIMD3<Float>(
                    cosYaw,
                    0,
                    sinYaw
                )


            let yAxis =
                SIMD3<Float>(
                    0,
                    1,
                    0
                )


            let zAxis =
                SIMD3<Float>(
                    -sinYaw,
                    0,
                    cosYaw
                )


            // Keep the original floor height.
            //
            // Multi-tag stabilization should not move
            // the complete map vertically.
            let mapHeight =
                currentTransform
                    .columns.3.y


            return simd_float4x4(
                columns: (

                    SIMD4<Float>(
                        xAxis.x,
                        xAxis.y,
                        xAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        yAxis.x,
                        yAxis.y,
                        yAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        zAxis.x,
                        zAxis.y,
                        zAxis.z,
                        0
                    ),

                    SIMD4<Float>(
                        translation.x,
                        mapHeight,
                        translation.y,
                        1
                    )
                )
            )
        }


        // MARK: - Reset Multi-Tag Localization

        func resetMultiTagLocalization() {

            stabilizedMapWorldTransform =
                nil

            lastMapStabilization =
                .distantPast
        }
        
        // MARK: - Place AR Cube

        private func placeCube(
            for mapPose: AprilTagMapPose
        ) {

            // ARView must exist.
            guard let arView
            else {
                return
            }


            // --------------------------------------------------
            // Only one cube per AprilTag
            // --------------------------------------------------

            guard aprilTagAnchors[
                mapPose.id
            ] == nil

            else {
                return
            }


            // --------------------------------------------------
            // Cube
            // --------------------------------------------------

            let cubeSize:
                Float = 0.08


            let cube =
                ModelEntity(
                    mesh:
                        .generateBox(
                            size:
                                cubeSize
                        ),

                    materials: [
                        SimpleMaterial(
                            color:
                                .green,

                            isMetallic:
                                false
                        )
                    ]
                )


            // --------------------------------------------------
            // Anchor at detected AprilTag pose
            // --------------------------------------------------

            let anchor =
                AnchorEntity(
                    world:
                        mapPose.worldTransform
                )


            // --------------------------------------------------
            // Add cube
            // --------------------------------------------------

            anchor.addChild(
                cube
            )


            arView.scene.addAnchor(
                anchor
            )


            // --------------------------------------------------
            // Store anchor
            // --------------------------------------------------

            aprilTagAnchors[
                mapPose.id
            ] = anchor


            print(
                "# AR CUBE PLACED | TAG \(mapPose.id)"
            )
        }
        
        // MARK: - Localize Map Anchor

        private func localizeMapAnchor(
            with referenceWorldTransform:
                simd_float4x4
        ) {

            guard let mapAnchor
            else {
                return
            }


            mapAnchor.setTransformMatrix(
                referenceWorldTransform,
                relativeTo:
                    nil
            )

            let mapRoot =
                ensureMapRoot(
                    in:
                        mapAnchor
                )


            renderTrackIfNeeded(
                in:
                    mapRoot
            )

            // Attach the virtual robot to the
            // localized map coordinate system.
            attachSimulationToMap()

            attachOccluderToMap()


            print(
                "# MAP ANCHOR LOCALIZED"
            )
        }


        private func ensureMapRoot(
            in mapAnchor: Entity
        ) -> Entity {

            if let mapRoot {
                return mapRoot
            }


            let mapRoot =
                Entity()

            mapRoot.name =
                "MapRoot"

            mapAnchor.addChild(
                mapRoot
            )

            self.mapRoot =
                mapRoot


            return mapRoot
        }


        private func renderTrackIfNeeded(
            in mapRoot: Entity
        ) {

            guard hasRenderedTrack == false,
                  let gameMap
            else {
                return
            }


            trackRenderer.render(
                trackPoints:
                    gameMap.trackPoints,

                aprilTags:
                    gameMap.aprilTags,

                parent:
                    mapRoot
            )

            hasRenderedTrack =
                true
        }


        // MARK: - Update Runtime Map Objects

        func updateRuntimeMapObjects(
            _ activeObjects:
                [PlacedMapObject]
        ) {

            guard let mapAnchor
            else {
                return
            }


            // --------------------------------------------------
            // Active IDs
            // --------------------------------------------------

            let activeIDs =
                Set(
                    activeObjects.map {
                        $0.id
                    }
                )


            // --------------------------------------------------
            // Remove AR entities whose gameplay object disappeared
            // --------------------------------------------------

            let removedIDs =
                mapObjectEntities.keys.filter {
                    activeIDs.contains($0) == false
                }


            for id in removedIDs {

                mapObjectEntities[id]?
                    .removeFromParent()

                mapObjectEntities[id] =
                    nil

                animatedMapObjects.removeAll {
                    $0.entity.name == "ARMapObject-\(id)"
                }


                print(
                    "# AR OBJECT REMOVED | \(id)"
                )
            }


            // --------------------------------------------------
            // Add objects which do not yet exist in AR
            // --------------------------------------------------

            for object in activeObjects {

                guard mapObjectEntities[
                    object.id
                ] == nil
                else {
                    continue
                }


                guard let modelName =
                    object.type.modelName
                else {
                    continue
                }


                do {

                    let entity =
                        try Entity.load(
                            named:
                                modelName
                        )


                    let objectRoot =
                        Entity()

                    objectRoot.name =
                        "ARMapObject-\(object.id)"


                    let basePosition =
                        SIMD3<Float>(
                            object.x,
                            0,
                            object.z
                        )

                    objectRoot.position =
                        basePosition


                    let uprightRotation =
                        simd_quatf(
                            angle:
                                0,

                            axis:
                                SIMD3<Float>(
                                    0,
                                    0,
                                    1
                                )
                        )

                    let mapRotation =
                        simd_quatf(
                            angle:
                                object.rotation,

                            axis:
                                SIMD3<Float>(
                                    0,
                                    1,
                                    0
                                )
                        )

                    let baseOrientation =
                        mapRotation
                        * uprightRotation

                    objectRoot.orientation =
                        baseOrientation

                    entity.scale *=
                        SIMD3<Float>(
                            repeating:
                                object.type
                                    .arModelScale
                        )

                    objectRoot.addChild(
                        entity
                    )

                    mapAnchor.addChild(
                        objectRoot
                    )


                    mapObjectEntities[
                        object.id
                    ] =
                        objectRoot

                    if object.type != .oil {

                        animatedMapObjects.append(
                            AnimatedMapObject(
                                entity:
                                    objectRoot,

                                basePosition:
                                    basePosition,

                                baseOrientation:
                                    baseOrientation,

                                phase:
                                    Float(
                                        animatedMapObjects.count
                                    )
                                    * 0.7
                            )
                        )

                        startMapObjectAnimationIfNeeded()
                    }


                    print(
                        "# AR OBJECT ADDED | \(object.type.name)"
                    )

                } catch {

                    print(
                        "# AR OBJECT LOAD FAILED | \(modelName) | \(error)"
                    )
                }
            }
        }


        // MARK: - Update Shit Dots

        func updateShitDots(
            _ dots:
                [ShitDot]
        ) {

            guard let mapAnchor
            else {
                return
            }


            // Remove dots which no longer exist.
            let activeIDs =
                Set(
                    dots.map {
                        $0.id
                    }
                )


            for id in shitDotEntities.keys
                where activeIDs.contains(id) == false {

                shitDotEntities[id]?
                    .removeFromParent()

                shitDotEntities[id] =
                    nil
            }


            // Add new dots.
            for dot in dots {

                guard shitDotEntities[
                    dot.id
                ] == nil

                else {
                    continue
                }


                let mesh =
                    MeshResource.generateCylinder(
                        height:
                            0.003,

                        radius:
                            dot.radius
                    )


                let material =
                    SimpleMaterial(
                        color:
                            .brown,

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
                    SIMD3<Float>(
                        dot.position.x,

                        // Slightly above the road.
                        0.001,

                        dot.position.y
                    )


                mapAnchor.addChild(
                    entity
                )


                shitDotEntities[
                    dot.id
                ] =
                    entity
            }
        }


        // MARK: - Update Coins

        func updateCoins(
            _ coins:
                [GameCoin]
        ) {

            coinRenderer.update(
                coins:
                    coins,

                parent:
                    mapRoot,

                mapAnchor:
                    mapAnchor,

                arView:
                    arView
            )
        }


        // ======================================================
        // MARK: - Update Runtime Eggs
        // ======================================================

        func updateEggs(
            _ eggs:
                [RuntimeEgg],

            robotPose:
                RobotPose?
        ) {

            guard let mapRoot
            else {
                return
            }


            let eggCup =
                gameMap?
                    .mapObjects
                    .first {

                        $0.type
                            == .eggCup
                    }


            eggRenderer.update(
                eggs:
                    eggs,

                robotPose:
                    robotPose,

                eggCup:
                    eggCup,

                parent:
                    mapRoot
            )
        }


        func clearRuntimeGameARContent() {

            for entity in mapObjectEntities.values {

                entity.removeFromParent()
            }

            mapObjectEntities
                .removeAll()

            for entity in shitDotEntities.values {

                entity.removeFromParent()
            }

            shitDotEntities
                .removeAll()

            coinRenderer
                .clear()

            eggRenderer
                .clear()
        }


        private func startMapObjectAnimationIfNeeded() {

            guard mapObjectAnimationSubscription == nil,
                  let arView
            else {
                return
            }


            mapObjectAnimationSubscription =
                arView.scene.subscribe(
                    to:
                        SceneEvents.Update.self
                ) { [weak self] event in

                    guard let self
                    else {
                        return
                    }


                    self.mapObjectAnimationTime +=
                        Float(
                            event.deltaTime
                        )


                    for object in self.animatedMapObjects {

                        let time =
                            self.mapObjectAnimationTime
                            + object.phase

                        let verticalOffset =
                            sin(time * 3.2)
                            * 0.018

                        let rotationOffset =
                            sin(time * 4.0)
                            * 0.10


                        object.entity.position =
                            object.basePosition
                            + SIMD3<Float>(
                                0,
                                verticalOffset,
                                0
                            )

                        object.entity.orientation =
                            simd_quatf(
                                angle:
                                    rotationOffset,

                                axis:
                                    SIMD3<Float>(
                                        0,
                                        1,
                                        0
                                    )
                            )
                            * object.baseOrientation
                    }
                }
        }


        // MARK: - Update Simulation Entity

        func attachSimulationToMap() {

            guard
                let mapRoot,
                let simulationRoot
            else {
                return
            }


            if simulationRoot.parent !== mapRoot {

                simulationRoot.removeFromParent()

                mapRoot.addChild(
                    simulationRoot
                )
            }
        }
        
        

        func attachOccluderToMap() {

            guard
                let mapRoot,
                let occlusionRoot
            else {
                return
            }


            if occlusionRoot.parent !== mapRoot {

                occlusionRoot.removeFromParent()

                mapRoot.addChild(
                    occlusionRoot
                )
            }
        }
        



    }
}
