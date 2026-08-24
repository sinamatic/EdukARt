//
//  EduardSimulation.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//

//
//  EduardSimulation.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//

import RealityKit
import simd
import UIKit


final class EduardSimulation {

    let name =
        "Eduard Simulation"

    let modelName =
        "eduard-mecanum"

    let collisionSize =
        SIMD3<Float>(
            0.43,
            0.8,
            0.28
        )


    // MARK: - Pose

    var position:
        SIMD3<Float> = .zero

    var rotation:
        Float = 0


    // MARK: - Wheel Entities

    private var frontLeftWheel:
        Entity?

    private var frontRightWheel:
        Entity?

    private var backLeftWheel:
        Entity?

    private var backRightWheel:
        Entity?


    // MARK: - LED Entities

    private var frontLeftLED:
        ModelEntity?

    private var frontRightLED:
        ModelEntity?

    private var backLeftLED:
        ModelEntity?

    private var backRightLED:
        ModelEntity?


    // MARK: - Settings

    // Visual wheel rotation speed.
    private let wheelRotationSpeed:
        Float = 0.12

    // Change this axis if the wheels rotate
    // around the wrong local axis.
    private let wheelRotationAxis =
        SIMD3<Float>(
            0,
            0,
            1
        )


    // MARK: - Load Entity

    func loadEntity()
        async throws -> Entity {

        PerformanceLogger.shared.start(
            "Load Eduard USDZ"
        )

        let eduard =
            try await Entity(
                named: modelName
            )

        PerformanceLogger.shared.end(
            "Load Eduard USDZ"
        )

        eduard.name =
            name

        bind(
            entity: eduard
        )

        return eduard
    }


    // MARK: - Bind Model Parts

    /// Finds the wheels and LEDs inside the loaded
    /// RealityKit entity hierarchy.
    ///
    /// Call this again when using a cloned Eduard entity.
    func bind(
        entity eduard: Entity
    ) {

        frontLeftWheel =
            eduard.findEntity(
                named: "wheel-front-left"
            )

        frontRightWheel =
            eduard.findEntity(
                named: "wheel-front-right"
            )

        backLeftWheel =
            eduard.findEntity(
                named: "wheel-back-left"
            )

        backRightWheel =
            eduard.findEntity(
                named: "wheel-back-right"
            )


        frontLeftLED =
            eduard.findEntity(
                named: "chassis-led-front-left"
            ) as? ModelEntity

        frontRightLED =
            eduard.findEntity(
                named: "chassis-led-front-right"
            ) as? ModelEntity

        backLeftLED =
            eduard.findEntity(
                named: "chassis-led-back-left"
            ) as? ModelEntity

        backRightLED =
            eduard.findEntity(
                named: "chassis-led-back.right"
            ) as? ModelEntity
    }


    // MARK: - Wheel Animation

    /// Rotates all four wheels according to
    /// Mecanum drive input.
    ///
    /// forward:
    ///     -1 ... +1
    ///
    /// sideways:
    ///     -1 ... +1
    ///
    /// turn:
    ///     -1 ... +1
    func updateWheels(
        forward: Float,
        sideways: Float,
        turn: Float
    ) {

        // Basic Mecanum wheel mixing.
        let frontLeft =
            forward
            + sideways
            + turn

        let frontRight =
            forward
            - sideways
            - turn

        let backLeft =
            forward
            - sideways
            + turn

        let backRight =
            forward
            + sideways
            - turn


        rotateWheel(
            frontLeftWheel,
            amount: frontLeft
        )

        rotateWheel(
            frontRightWheel,
            amount: frontRight
        )

        rotateWheel(
            backLeftWheel,
            amount: backLeft
        )

        rotateWheel(
            backRightWheel,
            amount: backRight
        )
    }


    // MARK: - Rotate Wheel

    private func rotateWheel(
        _ wheel: Entity?,
        amount: Float
    ) {

        guard let wheel else {
            return
        }

        guard abs(amount) > 0.01 else {
            return
        }


        let rotation =
            simd_quatf(
                angle:
                    amount
                    * wheelRotationSpeed,

                axis:
                    wheelRotationAxis
            )


        wheel.transform.rotation =
            wheel.transform.rotation
            * rotation
    }


    // MARK: - Front Lights

    func setFrontLights(
        color: UIColor
    ) {

        setLEDColor(
            frontLeftLED,
            color: color
        )

        setLEDColor(
            frontRightLED,
            color: color
        )
    }


    // MARK: - Back Lights

    func setBackLights(
        color: UIColor
    ) {

        setLEDColor(
            backLeftLED,
            color: color
        )

        setLEDColor(
            backRightLED,
            color: color
        )
    }


    // MARK: - Individual Lights

    func setFrontLeftLight(
        color: UIColor
    ) {

        setLEDColor(
            frontLeftLED,
            color: color
        )
    }


    func setFrontRightLight(
        color: UIColor
    ) {

        setLEDColor(
            frontRightLED,
            color: color
        )
    }


    func setBackLeftLight(
        color: UIColor
    ) {

        setLEDColor(
            backLeftLED,
            color: color
        )
    }


    func setBackRightLight(
        color: UIColor
    ) {

        setLEDColor(
            backRightLED,
            color: color
        )
    }


    // MARK: - Set LED Color

    private func setLEDColor(
        _ led: ModelEntity?,
        color: UIColor
    ) {

        guard let led else {
            return
        }


        // UnlitMaterial stays clearly visible
        // independently of environmental lighting.
        let material =
            UnlitMaterial(
                color: color
            )


        led.model?.materials =
            [material]
    }
}
