//
//  EduardSimulation.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//

import simd

final class EduardSimulation {

    let name = "Eduard Simulation"

    let chassisModelName = "eduard-chassis-red"

    let frontLeftWheelModelName = "eduard-wheel-front-left"
    let frontRightWheelModelName = "eduard-wheel-front-right"
    let backLeftWheelModelName = "eduard-wheel-back-left"
    let backRightWheelModelName = "eduard-wheel-back-right"

    let collisionSize = SIMD3<Float>(
        0.43,
        0.8,
        0.28
    )

    var position: SIMD3<Float> = .zero
    var rotation: Float = 0
}
