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


    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {

        Coordinator()
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

        arView.debugOptions.insert(
            .showStatistics
        )


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


        // Translation

        eduard.position.x +=
            sideways * movementSpeed

        eduard.position.z +=
            forward * movementSpeed


        // Rotation

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


                // ----------------------------------------------
                // Localize every detected AprilTag
                // ----------------------------------------------
                
                // Select smallest detected non-zero tag
                // as map reference.
                
                aprilTagLocalization.selectReferenceTag(
                    from: detections
                )
                
                for detection in detections {

                    guard let mapPose =
                        aprilTagLocalization
                            .localize(

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


                    // ------------------------------------------
                    // Console Output
                    // ------------------------------------------

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
    }
}
