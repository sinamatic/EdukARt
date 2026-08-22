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
        
        PerformanceLogger.shared.start(
                "Load Eduard USDZ"
            )

            let eduard = try await Entity(
                named: modelName
            )

            PerformanceLogger.shared.end(
                "Load Eduard USDZ"
            )


        eduard.name = name
        
        // ToDo rotate wheels

        if let frontLeftWheel = eduard.findEntity(
            named: "wheel_front_left"
        ) {
//            frontLeftWheel.transform.rotation =
//                simd_quatf(
//                    angle: .pi / 2,
//                    axis: SIMD3<Float>(0, 0, 1)
//                )
        }

        return eduard
    }
}
