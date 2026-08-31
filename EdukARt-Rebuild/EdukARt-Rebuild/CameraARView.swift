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


struct CameraARView: UIViewRepresentable {

    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var joystickMonitor: JoystickMonitor
    @ObservedObject var turnJoystickMonitor: JoystickMonitor

    @ObservedObject var mapBuilder: AprilTagMapBuilder
    @ObservedObject var controller:
        RobotController
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

    init(
        eduardModelStore: EduardModelStore,
        joystickMonitor: JoystickMonitor,
        turnJoystickMonitor: JoystickMonitor,
        mapBuilder: AprilTagMapBuilder,
        controller: RobotController,
        gameMap: GameMap? = nil,
        localizationResetID: Int = 0,
        requiredReferenceTagID: Int = 0,
        onReferenceTagLocalized: @escaping () -> Void = {},
        onRobotPoseUpdated: @escaping (RobotPose) -> Void = { _ in }
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
                onRobotPoseUpdated
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


            simulationRoot.addChild(
                eduard
            )

            context.coordinator.simulationRoot =
                simulationRoot

            context.coordinator.eduard =
                eduard

            controller.eduardSimulation.show(
                entity:
                    simulationRoot
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
        }
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
        var eduard: Entity?
        private let trackRenderer =
            ARTrackRenderer()
        var hasRenderedTrack =
            false

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
        
        init(
            mapBuilder: AprilTagMapBuilder,
            controller: RobotController,
            gameMap: GameMap?,
            requiredReferenceTagID: Int,
            onReferenceTagLocalized: @escaping () -> Void,
            onRobotPoseUpdated: @escaping (RobotPose) -> Void
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


            super.init()


            if requiredReferenceTagID > 0 {

                aprilTagLocalization
                    .setReferenceTag(
                        id:
                            requiredReferenceTagID
                    )
            }
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

                parent:
                    mapRoot
            )

            hasRenderedTrack =
                true
        }


        // MARK: - Update Simulation Entity

        func attachSimulationToMap() {

            guard
                let mapAnchor,
                let simulationRoot
            else {
                return
            }


            if simulationRoot.parent !== mapAnchor {

                simulationRoot.removeFromParent()

                mapAnchor.addChild(
                    simulationRoot
                )
            }
        }
        



    }
}
