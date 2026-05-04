//
//  SimulatedRobot2.swift
//  EdukARt
//

import Foundation
import simd

final class SimulatedRobot2: RobotTarget {
    let name: String
    let chassisModelName: String = "eduard-red-chassis"
    let frontLeftWheelModelName: String = "Mechanum_frontLeft"
    let frontRightWheelModelName: String = "Mechanum_frontRight"
    let backLeftWheelModelName: String = "Mechanum_backLeft"
    let backRightWheelModelName: String = "Mechanum_backRight"
    let collisionSize = SIMD3<Float>(0.43, 0.8, 0.28)
    var position: SIMD3<Float>

    init(name: String = "Robot 2", position: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) {
        self.name = name
        self.position = position
    }

    func move(input: ControlInput, step: Float) -> SIMD3<Float> {
        var candidatePosition = position

        if input.isForwardPressed {
            candidatePosition.z -= step
        }

        if input.isBackwardPressed {
            candidatePosition.z += step
        }

        if input.isLeftPressed {
            candidatePosition.x -= step
        }

        if input.isRightPressed {
            candidatePosition.x += step
        }

        return candidatePosition
    }
}
