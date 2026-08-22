//
//  EduardSimulation.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//

import simd

import RealityKit
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

    func loadEntity() async throws -> Entity {

        print("Start loading Eduard")

        let eduard = Entity()
        eduard.name = name

        let chassis = try await Entity(
            named: chassisModelName
        )

        let frontLeftWheel = try await Entity(
            named: frontLeftWheelModelName
        )

        let frontRightWheel = try await Entity(
            named: frontRightWheelModelName
        )

        let backLeftWheel = try await Entity(
            named: backLeftWheelModelName
        )

        let backRightWheel = try await Entity(
            named: backRightWheelModelName
        )

        eduard.addChild(chassis)
        eduard.addChild(frontLeftWheel)
        eduard.addChild(frontRightWheel)
        eduard.addChild(backLeftWheel)
        eduard.addChild(backRightWheel)

        print("Eduard completely loaded")

        return eduard
    }
}
