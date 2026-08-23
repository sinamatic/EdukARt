//
//  CameraARView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//  https://developer.apple.com/documentation/realitykit/loading-entities-from-a-file
//  https://developer.apple.com/documentation/realitykit/entity/load(named:in:)

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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        
        PerformanceLogger.shared.end(
            "Button to CameraARView"
        )

        PerformanceLogger.shared.start(
            "Create ARView"
        )
       
        // Create AR View
        let arView = ARView(
            frame: .zero,
            cameraMode: .ar,
                       automaticallyConfigureSession: false
        )
        
        context.coordinator.arView = arView
        
        // Coordinator constantly AR Frames
        arView.session.delegate =
            context.coordinator
        
        // Dection not on Main Thread anymore
        arView.session.delegateQueue =
            DispatchQueue(
                label: "AprilTagDetectionQueue",
                qos: .userInitiated
            )
        
        func makeCoordinator() -> Coordinator {
            Coordinator()
        }
        
        
        
        PerformanceLogger.shared.end(
            "Create ARView"
        )
        
        arView.debugOptions.insert(
            .showStatistics
        )
        
        
        

        let configuration =
            ARWorldTrackingConfiguration()

        configuration.planeDetection = [
            .horizontal
        ]

        PerformanceLogger.shared.start(
            "Start ARSession"
        )
        arView.session.run(
            configuration
        )
        
        PerformanceLogger.shared.end(
            "Start ARSession"
        )

        PerformanceLogger.shared.start(
            "Find Floor Anchor"
        )

        let anchor = AnchorEntity(
            plane: .horizontal,
            classification: .floor,
            minimumBounds: [0.3, 0.3]
        )
        
        arView.scene.addAnchor(anchor)

        
        
        // Load preloaded eduard
        if let model = eduardModelStore.model {
            let eduard = model.clone(recursive: true)
            anchor.addChild(eduard)
            
            context.coordinator.eduard = eduard

            print("Used preloaded Eduard model")
            
            
            
        } else {
            print("Eduard model is not loaded yet")
        }
        
        
        
        

        
        

        return arView
        
        
    }

    func updateUIView(
        _ uiView: ARView,
        context: Context
    ) {

        guard let eduard = context.coordinator.eduard else {
            return
        }

        let forward =
            Float(
                joystickMonitor.xyPoint.y
                / 180
            )

        let turn =
            Float(
                -turnJoystickMonitor.xyPoint.x
                / 120
            )

        let sideways =
            Float(
                joystickMonitor.xyPoint.x
                / 180
            )

        let movementSpeed: Float = 0.02
        let rotationSpeed: Float = 0.03

        eduard.position.x += sideways * movementSpeed
        eduard.position.z += forward * movementSpeed

        if abs(turn) > 0.05 {
            let rotation =
                simd_quatf(
                    angle: turn * rotationSpeed,
                    axis: SIMD3<Float>(0, 1, 0)
                )

            eduard.transform.rotation =
                rotation * eduard.transform.rotation
        }
    }
    
    
    final class Coordinator: NSObject, ARSessionDelegate {
        
        var eduard: Entity?
        
        // place cube on top of april tag
        weak var arView: ARView?

        var debugAnchor: AnchorEntity?
        var trackedTagID: Int?
        var didPrintTableHeader = false
        
        // April Tag sample from https://github.com/keyqcloud/SwiftAprilTag
        let detector = try! Detector(
            families: [.tag36h11]
        )
        
        var isDetecting = false
        var frameCounter = 0


        func session(
            _ session: ARSession,
            didUpdate frame: ARFrame
        ) {

            // Check only every 6th frame
            frameCounter += 1

            guard frameCounter % 6 == 0 else {
                return
            }

            // Prevent multiple detections at the same time
            guard isDetecting == false else {
                return
            }

            isDetecting = true

            defer {
                isDetecting = false
            }

            let pixelBuffer = frame.capturedImage

            do {
                let detections = try detector.detect(
                    pixelBuffer: pixelBuffer
                )
                
                // source: SwiftAprilTag's documented pose-estimation example

                let cameraMatrix = frame.camera.intrinsics

                let intrinsics = CameraIntrinsics(
                    fx: Double(cameraMatrix.columns.0.x),
                    fy: Double(cameraMatrix.columns.1.y),
                    cx: Double(cameraMatrix.columns.2.x),
                    cy: Double(cameraMatrix.columns.2.y)
                )

                let tagSize = 0.096

                for detection in detections {

                    print("# AprilTag ID: \(detection.id)")

                    for (index, corner) in detection.corners.enumerated() {
                        print(
                            "# Corner \(index): \(corner)"
                        )
                    }

                    if let pose = detection.estimatePose(
                        intrinsics: intrinsics,
                        tagSize: tagSize
                    ) {

//                        print(
//                            "# Position relative to camera:",
//                            pose.translation
//                        )
//
//                        print(
//                            "# Rotation:",
//                            pose.rotation
//                        )
//
//                        print(
//                            "# Reprojection error:",
//                            pose.reprojectionError
//                        )
//
//                        print("# -------------------------")
                        
                        // Lock the test onto the first detected AprilTag
                        if trackedTagID == nil {
                            trackedTagID = detection.id
                        }

                        guard detection.id == trackedTagID else {
                            continue
                        }


                        // MARK: Camera coordinates

                        let cameraX = Float(pose.translation[0])
                        let cameraY = Float(pose.translation[1])
                        let cameraZ = Float(pose.translation[2])


                        // MARK: Convert AprilTag camera coordinates to ARKit camera coordinates

                        // AprilTag / OpenCV:
                        // x = right
                        // y = down
                        // z = forward
                        //
                        // ARKit:
                        // x = right
                        // y = up
                        // z = backward

                        let tagPositionCamera = SIMD4<Float>(
                            cameraX,
                            -cameraY,
                            -cameraZ,
                            1
                        )


                        // MARK: Camera coordinates -> ARKit world coordinates

                        let tagPositionWorld =
                            frame.camera.transform * tagPositionCamera

                        let worldPosition = SIMD3<Float>(
                            tagPositionWorld.x,
                            tagPositionWorld.y,
                            tagPositionWorld.z
                        )


                        // MARK: Debug Cube

                        DispatchQueue.main.async { [weak self] in

                            guard let self,
                                  let arView = self.arView
                            else {
                                return
                            }

                            let cubeSize: Float = 0.096 // same as April Tag size

                            // places Green Cube on top of first detected April Tag
                            if self.debugAnchor == nil {

                                let anchor = AnchorEntity(
                                    world: worldPosition
                                )

                                let mesh = MeshResource.generateBox(
                                    size: cubeSize
                                )

                                let color = UIColor(
                                    Color("BrandGreen")
                                )
                                .withAlphaComponent(0.5) // transparency

                                let material = SimpleMaterial(
                                    color: color,
                                    isMetallic: false
                                )

                                let cube = ModelEntity(
                                    mesh: mesh,
                                    materials: [material]
                                )

                                anchor.addChild(cube)
                                arView.scene.addAnchor(anchor)

                                self.debugAnchor = anchor

                            } else {

                                self.debugAnchor?.position =
                                    worldPosition
                            }
                        }


                        // MARK: Console Table
                        if didPrintTableHeader == false {

                            print(
                                "# ID | Cam X | Cam Y | Cam Z | World X | World Y | World Z | Error"
                            )

                            didPrintTableHeader = true
                        }

                        print(
                            String(
                                format:
                                    "# %d | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.2e",
                                detection.id,
                                cameraX,
                                cameraY,
                                cameraZ,
                                worldPosition.x,
                                worldPosition.y,
                                worldPosition.z,
                                pose.reprojectionError
                            )
                        )
                    }
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
    
