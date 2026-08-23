//
//  CameraARView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
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

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {

        Coordinator(
            mapBuilder: mapBuilder
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
        // World Anchor
        // --------------------------------------------------

        let worldAnchor =
            AnchorEntity(
                world: .zero
            )

        arView.scene.addAnchor(
            worldAnchor
        )

        context.coordinator.worldAnchor =
            worldAnchor


        // --------------------------------------------------
        // Load preloaded Eduard
        // --------------------------------------------------

        if let model =
            eduardModelStore.model {

            let eduard =
                model.clone(
                    recursive: true
                )

            worldAnchor.addChild(
                eduard
            )

            context.coordinator.eduard =
                eduard

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

        guard let eduard =
            context.coordinator.eduard
        else {
            return
        }


        // --------------------------------------------------
        // Joystick Control
        // --------------------------------------------------

        let forward =
            Float(
                joystickMonitor.xyPoint.y
                / 180
            )

        let sideways =
            Float(
                joystickMonitor.xyPoint.x
                / 180
            )

        let turn =
            Float(
                -turnJoystickMonitor.xyPoint.x
                / 120
            )


        let movementSpeed: Float =
            0.02

        let rotationSpeed: Float =
            0.03


//        // Translation - Forward is always x, rotation of eduard not relevant
//
//        eduard.position.x +=
//            sideways * movementSpeed
//
//        eduard.position.z +=
//            forward * movementSpeed
        
        
        // --------------------------------------------------
        // Movement relative to Eduard's current orientation
        // --------------------------------------------------

        // Local movement:
        // X = sideways
        // Z = forward/backward
        let localMovement =
            SIMD3<Float>(
                sideways,
                -forward,
                0
            )

        // Rotate movement vector with Eduard's
        // current orientation.
        let worldMovement =
            eduard.transform.rotation
            .act(
                localMovement
            )

        // Apply movement in AR world coordinates.
        eduard.position +=
            worldMovement
            * movementSpeed


        // --------------------------------------------------
        // Rotation
        // --------------------------------------------------

        if abs(turn) > 0.05 {

            let rotation =
                simd_quatf(
                    angle:
                        turn
                        * rotationSpeed,

                    axis:
                        SIMD3<Float>(
                            0,
                            1,
                            0
                        )
                )

            eduard.transform.rotation =
                rotation
                * eduard.transform.rotation
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
        var worldAnchor: AnchorEntity?
        var eduard: Entity?
        
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
        // Eduard AprilTag Localization
        // --------------------------------------------------
        //
        // Eduard is placed only once on the first
        // successfully localized AprilTag.
        // --------------------------------------------------

        var isEduardLocalized =
            false
        
        // --------------------------------------------------
        // AprilTag Map Builder
        // --------------------------------------------------
        let mapBuilder: AprilTagMapBuilder
        
        init(
            mapBuilder: AprilTagMapBuilder
        ) {

            self.mapBuilder =
                mapBuilder
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

                aprilTagLocalization.selectReferenceTag(
                    from: detections
                )
                
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

                    guard let mapPose =
                        aprilTagLocalization.localize(
                            detection: detection,
                            frame: frame,
                            intrinsics: intrinsics
                        )
                    else {
                        continue
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

                    DispatchQueue.main.async {

                        self.placeCube(
                            for: mapPose
                        )
                    }
                    
                    // ----------------------------------------------
                    // Place Eduard on first localized AprilTag
                    // ----------------------------------------------
                    
                    DispatchQueue.main.async {

                        self.placeEduard(
                            on: mapPose
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


            } catch {

                print(
                    "# AprilTag detection error:",
                    error
                )
            }
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
        
        // MARK: - Place Eduard on First AprilTag

        private func placeEduard(
            on mapPose: AprilTagMapPose
        ) {

            // --------------------------------------------------
            // Only localize Eduard once
            // --------------------------------------------------

            guard isEduardLocalized == false
            else {
                return
            }


            // --------------------------------------------------
            // Eduard model must exist
            // --------------------------------------------------

            guard let eduard
            else {
                return
            }


            // --------------------------------------------------
            // Apply complete AprilTag world transform
            // --------------------------------------------------
            //
            // Position AND rotation are copied from the
            // AprilTag into Eduard.
            // --------------------------------------------------

//            eduard.setTransformMatrix(
//                mapPose.worldTransform,
//                relativeTo: nil
//            ) // Rotated 180° in X
            
            let modelRotationOffset =
                simd_float4x4(
                    simd_quatf(
                        angle: .pi,
                        axis: SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                    )
                )

            let correctedTransform =
                mapPose.worldTransform
                * modelRotationOffset

            eduard.setTransformMatrix(
                correctedTransform,
                relativeTo: nil
            )

            

            // --------------------------------------------------
            // Lock localization
            // --------------------------------------------------

            isEduardLocalized =
                true


            print(
                "# EDUARD LOCALIZED | APRILTAG \(mapPose.id)"
            )
        }
        



    }
}
