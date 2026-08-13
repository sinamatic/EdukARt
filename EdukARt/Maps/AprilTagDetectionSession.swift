//
//  AprilTagDetectionSession.swift
//  EdukARt
//

import ARKit
import Combine

final class AprilTagDetectionSession: NSObject, ObservableObject, ARSessionDelegate {
    
    @Published var detectedTagNames: [String] = []
    
    func session(
        _ session: ARSession,
        didAdd anchors: [ARAnchor]
    ) {
        for anchor in anchors {
            
            guard let imageAnchor = anchor as? ARImageAnchor else {
                continue
            }
            
            guard let name = imageAnchor.referenceImage.name else {
                continue
            }
            
            if detectedTagNames.contains(name) == false {
                detectedTagNames.append(name)
            }
        }
    }
}


