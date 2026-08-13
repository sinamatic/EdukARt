//
//  EduardRobot.swift
//  EdukARt
//
//  - Beschreibt Eduard als 3D-Roboter in der AR-/Spielwelt.
//  - Nutzt dieselben Modellnamen und Kollisionsmasse fuer Simulation und echten Roboter.
//  - Die Position wird entweder per Steuerkreuz simuliert oder per AprilTag synchronisiert.

import Foundation
import simd

final class EduardRobot {
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
