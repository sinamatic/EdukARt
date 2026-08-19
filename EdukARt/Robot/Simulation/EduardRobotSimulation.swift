//
//  EduardRobot.swift
//  EdukARt
//

import Foundation
import simd

final class EduardRobotSimulation {
    
    let name: String
    
    let chassisModelName = "eduard-red-chassis"
    
    let frontLeftWheelModelName =
        "Mechanum_frontLeft"
    
    let frontRightWheelModelName =
        "Mechanum_frontRight"
    
    let backLeftWheelModelName =
        "Mechanum_backLeft"
    
    let backRightWheelModelName =
        "Mechanum_backRight"
    
    
    let collisionSize =
        SIMD3<Float>(
            0.43,
            0.8,
            0.28
        )
    
    
    var position: SIMD3<Float>
    var rotation: Float
    
    
    init(
        name: String = "Eduard Simulation",
        position: SIMD3<Float> = .zero,
        rotation: Float = 0
    ) {
        self.name = name
        self.position = position
        self.rotation = rotation
    }
}
