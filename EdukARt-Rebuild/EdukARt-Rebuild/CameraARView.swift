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

            context.coordinator.simulationRoot =
                simulationRoot

            context.coordinator.eduard =
                eduard

            let occlusionRoot =
                simulationRoot.clone(
                    recursive:
                        true
                )

            context.coordinator.occlusionRoot =
                occlusionRoot

            controller.eduardSimulation.show(
                entity:
                    simulationRoot
            )

            controller.eduardOccluder.show(
                entity:
                    occlusionRoot
            )

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

        // MARK: - Runtime Game AR Content

        var mapObjectEntities:
            [UUID: Entity] = [:]

        var shitDotEntities:
            [UUID: Entity] = [:]

        let coinRenderer =
            ARCoinRenderer()

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
                
                // --------------------------------------------------
                // Localize visible tags
                // --------------------------------------------------

                var didUpdateRobotPose =
                    false

                for detection in detections {

                    if let robotPose =
                        aprilTagLocalization.localizeRobot(
                            detection:
                                detection,

                            frame:
                                frame,

                            intrinsics:
                                intrinsics
                        ) {

                        didUpdateRobotPose =
                            true

                        DispatchQueue.main.async {

                            self.onRobotPoseUpdated(
                                robotPose
                            )
                        }
                    }


                    guard let mapPose =
                        aprilTagLocalization.localize(
                            detection: detection,
                            frame: frame,
                            intrinsics: intrinsics
                        )
                    else {
                        continue
                    }


                    if detection.id
                        == requiredReferenceTagID {

                        DispatchQueue.main.async {

                            if let mapReferenceWorldTransform =
                                self.aprilTagLocalization
                                    .mapReferenceWorldTransform {

                                let mapRootTransform =
                                    self.makeMapRootTransform(
                                        from:
                                            mapReferenceWorldTransform
                                    )


                                self.localizeMapAnchor(
                                    with:
                                        mapRootTransform
                                )
                            }

                            self
                                .onReferenceTagLocalized()
                        }
                    }


                    // ----------------------------------------------
                    // Update 2D AprilTag map
                    // ----------------------------------------------

                    DispatchQueue.main.async {

                        self.mapBuilder.add(
                            pose: mapPose
                        )
                    }


                    // ----------------------------------------------
                    // Place AR cube on AprilTag
                    // ----------------------------------------------

//                    DispatchQueue.main.async {
//
//                        self.placeCube(
//                            for: mapPose
//                        )
//                    }
                    
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

                if didUpdateRobotPose == false {

                    DispatchQueue.main.async {

                        self.onRobotPoseLost()
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
                            object.type == .oil
                            ? 0
                            : 0.02,
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
                                object.type == .oil
                                ? 0.15
                                : 0.3
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
                        0.008,

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
