
//
//  EduardPlayer.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//  Spielobjekt

import Foundation
import simd

struct EduardPlayer {
    var name: String = "Eduard"
    let chassisModelName: String = "eduard-red-chassis"
    
    let frontLeftWheelModelName: String = "Mechanum_frontLeft"
    let frontRightWheelModelName: String = "Mechanum_frontRight"
    let backLeftWheelModelName: String = "Mechanum_backLeft"
    let backRightWheelModelName: String = "Mechanum_backRight"

    var position: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
}
