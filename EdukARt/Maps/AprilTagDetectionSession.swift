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
    let worldTransform: simd_float4x4
    
    let centerOffset: Double
}

final class AprilTagDetectionSession: NSObject, ObservableObject, ARSessionDelegate {
    
    @Published private(set) var detectedTags: [DetectedAprilTag] = []
    @Published private(set) var scannedTags: [DetectedAprilTag] = []
    
    private let detector: Detector
    
    private var isDetecting = false
    private var frameCounter = 0
    
    private let tagSize = 0.096
    
    
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
                
                let centerOffset: Double
                let centerTranslation = pose.translation
                
                if centerTranslation.count >= 3 {
                    let x = Double(centerTranslation[0])
                    let y = Double(centerTranslation[1])
                    let z = Double(centerTranslation[2])
                    
                    if abs(z) > 0.001 {
                        let horizontalOffset = x / z
                        let verticalOffset = y / z
                        
                        centerOffset = sqrt(
                            horizontalOffset * horizontalOffset +
                            verticalOffset * verticalOffset
                        )
                    } else {
                        centerOffset = 1.0
                    }
                } else {
                    centerOffset = 1.0
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
                
                
                let worldTransform = self.worldTransform(
                    from: pose,
                    cameraTransform: cameraTransform
                )
                
                let worldPosition = SIMD3<Float>(
                    worldTransform.columns.3.x,
                    worldTransform.columns.3.y,
                    worldTransform.columns.3.z
                )
                
                
                return DetectedAprilTag(
                    id: detection.id,
                    distance: distance,
                    source: .iPhone,
                    worldPosition: worldPosition,
                    worldTransform: worldTransform,
                    centerOffset: centerOffset
                )
            }
            
            
            DispatchQueue.main.async {
                self.detectedTags = tags
                self.saveScannedTags(tags)
            }
        }
    }
    
    private func worldTransform(
        from pose: TagPose,
        cameraTransform: simd_float4x4
    ) -> simd_float4x4 {
        
        var tagTransform = pose.transform
        
        // SwiftAprilTag:
        // x = right
        // y = down
        // z = forward
        //
        // ARKit:
        // x = right
        // y = up
        // z = backwards
        
        let coordinateConversion = simd_float4x4(
            SIMD4<Float>(1,  0,  0, 0),
            SIMD4<Float>(0, -1,  0, 0),
            SIMD4<Float>(0,  0, -1, 0),
            SIMD4<Float>(0,  0,  0, 1)
        )
        
        tagTransform = coordinateConversion * tagTransform
        
        return cameraTransform * tagTransform
    }
    
    private func saveScannedTags(_ tags: [DetectedAprilTag]) {
        
        for tag in tags {
            
            // Tag #0 belongs to the robot.
            guard tag.id != 0 else {
                continue
            }
            
            // overwrites scanned tags with better / newer values
            // To Do make mean value from more measurements
            if let index = scannedTags.firstIndex(
                where: { $0.id == tag.id }
            ) {
                
                scannedTags[index] = tag
                
            } else {
                
                scannedTags.append(tag)
            }
        }
        
        scannedTags.sort {
            $0.id < $1.id
        }
    }
    func stop() {
        isDetecting = false
    }
}
