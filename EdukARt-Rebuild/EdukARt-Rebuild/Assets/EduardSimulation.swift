//
//  EduardSimulation.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//

import RealityKit
import simd

final class EduardSimulation {

    let name = "Eduard Simulation"
    let modelName = "eduard-mecanum"

    let collisionSize = SIMD3<Float>(
        0.43,
        0.8,
        0.28
    )

    var position: SIMD3<Float> = .zero
    var rotation: Float = 0

    func loadEntity() async throws -> Entity {

        let eduard = try await Entity(
            named: modelName
        )

        eduard.name = name

        if let frontLeftWheel = eduard.findEntity(
            named: "wheel_front_left"
        ) {
            print(
                "Front left wheel found:",
                frontLeftWheel.name
            )
        }

        return eduard
    }
}
