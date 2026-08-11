//
//  SimulatedEduard.swift
//  EdukARt
//

import Foundation
import simd

final class SimulatedEduard: RobotTarget {
    let name: String
    let chassisModelName: String = "eduard-red-chassis"
    let frontLeftWheelModelName: String = "Mechanum_frontLeft"
    let frontRightWheelModelName: String = "Mechanum_frontRight"
    let backLeftWheelModelName: String = "Mechanum_backLeft"
    let backRightWheelModelName: String = "Mechanum_backRight"
    let collisionSize = SIMD3<Float>(0.43, 0.8, 0.28)
    var position: SIMD3<Float>

    init(name: String = "Eduard", position: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) {
        self.name = name
        self.position = position
    }
}
