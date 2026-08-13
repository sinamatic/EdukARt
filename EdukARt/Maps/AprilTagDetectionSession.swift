//
//  AprilTagDetectionSession.swift
//  EdukARt
//

import ARKit
import Combine
import SwiftAprilTag


enum AprilTagSource {
    case iPhone
    case robotCamera
}


struct DetectedAprilTag: Identifiable {
    let id: Int
    let distance: Double
    let source: AprilTagSource
    let worldPosition: SIMD3<Float>
}


final class AprilTagDetectionSession: NSObject, ObservableObject, ARSessionDelegate {
    
    @Published private(set) var detectedTags: [DetectedAprilTag] = []
    
    private let detector: Detector
    
    private var isDetecting = false
    private var frameCounter = 0
    
    private let tagSize = 0.104
    
    
    override init() {
        detector = try! Detector(
            families: [.tag36h11]
        )
        
        super.init()
        
        detector.threadCount = 4
        detector.quadDecimate = 1.0
        detector.refineEdges = true
        detector.decodeSharpening = 0.25
    }
    
    
    func session(
        _ session: ARSession,
        didUpdate frame: ARFrame
    ) {
        
        frameCounter += 1
        
        // Only analyze every third camera frame.
        guard frameCounter % 3 == 0 else {
            return
        }
        
        // Do not start a new detection while the previous one is running.
        guard isDetecting == false else {
            return
        }
        
        isDetecting = true
        
        let pixelBuffer = frame.capturedImage
        let intrinsics = frame.camera.intrinsics
        
        // Position and orientation of the iPhone camera in the AR world.
        let cameraTransform = frame.camera.transform
        
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            defer {
                self.isDetecting = false
            }
            
            
            guard let detections = try? self.detector.detect(
                pixelBuffer: pixelBuffer,
                plane: 0
            ) else {
                return
            }
            
            
            let cameraIntrinsics = CameraIntrinsics(
                fx: Double(intrinsics.columns.0.x),
                fy: Double(intrinsics.columns.1.y),
                cx: Double(intrinsics.columns.2.x),
                cy: Double(intrinsics.columns.2.y)
            )
            
            
            let tags = detections.compactMap { detection -> DetectedAprilTag? in
                
                guard let pose = detection.estimatePose(
                    intrinsics: cameraIntrinsics,
                    tagSize: self.tagSize
                ) else {
                    return nil
                }
                
                
                let translation = pose.translation
                
                guard translation.count >= 3 else {
                    return nil
                }
                
                
                let x = Double(translation[0])
                let y = Double(translation[1])
                let z = Double(translation[2])
                
                let distance = Foundation.sqrt(
                    x * x +
                    y * y +
                    z * z
                )
                
                
                let worldPosition = self.worldPosition(
                    from: pose,
                    cameraTransform: cameraTransform
                )
                
                
                return DetectedAprilTag(
                    id: detection.id,
                    distance: distance,
                    source: .iPhone,
                    worldPosition: worldPosition
                )
            }
            
            
            DispatchQueue.main.async {
                self.detectedTags = tags
            }
        }
    }
    
    
    private func worldPosition(
        from pose: TagPose,
        cameraTransform: simd_float4x4
    ) -> SIMD3<Float> {
        
        let translation = pose.translation
        
        let x = Float(translation[0])
        let y = Float(translation[1])
        let z = Float(translation[2])
        
        
        // SwiftAprilTag:
        // x = right
        // y = down
        // z = forward
        //
        // ARKit:
        // x = right
        // y = up
        // -z = forward
        
        let tagPositionInCamera = SIMD4<Float>(
            x,
            -y,
            -z,
            1
        )
        
        
        let tagPositionInWorld =
            cameraTransform * tagPositionInCamera
        
        
        return SIMD3<Float>(
            tagPositionInWorld.x,
            tagPositionInWorld.y,
            tagPositionInWorld.z
        )
    }
}
