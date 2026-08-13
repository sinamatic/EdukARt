//
//  AprilTagDetectionSession.swift
//  EdukARt
//

import ARKit
import Combine
import SwiftAprilTag

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
        
        // Nicht jedes einzelne Kamerabild auswerten.
        guard frameCounter % 3 == 0 else {
            return
        }
        
        guard isDetecting == false else {
            return
        }
        
        isDetecting = true
        
        let pixelBuffer = frame.capturedImage
        let intrinsics = frame.camera.intrinsics
        
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
            
            let tags = detections.map { detection in
                
                let pose = detection.estimatePose(
                    intrinsics: cameraIntrinsics,
                    tagSize: self.tagSize
                )
                
                return DetectedAprilTag(
                    id: detection.id,
                    distance: self.distance(from: pose)
                )
            }
            
            DispatchQueue.main.async {
                self.detectedTags = tags
            }
        }
    }
    
    
    private func distance(from pose: TagPose?) -> Double? {
        
        guard let translation = pose?.translation,
              translation.count == 3 else {
            return nil
        }
        
        let x = Double(translation[0])
        let y = Double(translation[1])
        let z = Double(translation[2])
        
        return sqrt(x * x + y * y + z * z)
    }
}


struct DetectedAprilTag: Identifiable {
    
    let id: Int
    let distance: Double?
}
