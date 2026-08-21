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

    func loadEntity() throws -> Entity {

        print("Start loading Eduard")

        let eduard = Entity()
        eduard.name = name

        let chassis = try Entity.load(named: chassisModelName)
        print("Loaded chassis")

        let frontLeftWheel = try Entity.load(named: frontLeftWheelModelName)
        print("Loaded front left wheel")

        let frontRightWheel = try Entity.load(named: frontRightWheelModelName)
        print("Loaded front right wheel")

        let backLeftWheel = try Entity.load(named: backLeftWheelModelName)
        print("Loaded back left wheel")

        let backRightWheel = try Entity.load(named: backRightWheelModelName)
        print("Loaded back right wheel")

        eduard.addChild(chassis)
        eduard.addChild(frontLeftWheel)
        eduard.addChild(frontRightWheel)
        eduard.addChild(backLeftWheel)
        eduard.addChild(backRightWheel)

        print("Eduard completely loaded")

        return eduard
    }
}
