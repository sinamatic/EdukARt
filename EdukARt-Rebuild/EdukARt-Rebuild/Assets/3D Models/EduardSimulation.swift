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


import Foundation
import RealityKit
import simd
import UIKit


final class EduardSimulation {

    // MARK: - Robot State

    private(set) var pose:
        RobotPose = .zero


    // MARK: - AR Representation

    private(set) var entity:
        Entity?


    // MARK: - Wheels

    private var frontLeftWheel:
        Entity?

    private var frontRightWheel:
        Entity?

    private var backLeftWheel:
        Entity?

    private var backRightWheel:
        Entity?

    private var wheelAnimationDebugCounter =
        0


    // MARK: - Lights

    private var frontLeftLight:
        Entity?

    private var frontRightLight:
        Entity?

    private var backLeftLight:
        Entity?

    private var backRightLight:
        Entity?

    private var shitLightEffectTask:
        Task<Void, Never>?

    private var oilLightEffectTask:
        Task<Void, Never>?

    private var oilSpinTask:
        Task<Void, Never>?


    // MARK: - Settings

    private let movementUpdateInterval:
        Float = 0.01 // change speed of AR Model

    private let wheelRotationSpeed:
        Float = 0.12
    
    // MARK: - AR Model Alignment


    /// Visual offset from the AprilTag position.
    private let modelForwardOffset: Float =
    0.075


    // MARK: - Show

    func show(
        entity: Entity
    ) {

        self.entity =
            entity
        


        // Find wheel entities once.

        frontLeftWheel =
            entity.findEntity(
                named:
                    "wheel_front_left"
            )

        frontRightWheel =
            entity.findEntity(
                named:
                    "wheel_front_right"
            )

        backLeftWheel =
            entity.findEntity(
                named:
                    "wheel_back_left"
            )

        backRightWheel =
            entity.findEntity(
                named:
                    "wheel_back_right"
            )


        // Find light entities once.

        frontLeftLight =
            entity.findEntity(
                named:
                    "chassis_led_front_left"
            )

        frontRightLight =
            entity.findEntity(
                named:
                    "chassis_led_front_right"
            )

        backLeftLight =
            entity.findEntity(
                named:
                    "chassis_led_back_left"
            )

        backRightLight =
            entity.findEntity(
                named:
                    "chassis_led_back_right"
            )


        printEntityLookupStatus()
        applyDefaultLightMaterials()
        applyPose()
    }


    // MARK: - Hide

    func hide() {

        entity?
            .removeFromParent()

        entity =
            nil

        frontLeftWheel =
            nil

        frontRightWheel =
            nil

        backLeftWheel =
            nil

        backRightWheel =
            nil

        frontLeftLight =
            nil

        frontRightLight =
            nil

        backLeftLight =
            nil

        backRightLight =
            nil

        shitLightEffectTask?
            .cancel()

        oilLightEffectTask?
            .cancel()

        oilSpinTask?
            .cancel()
    }


    // MARK: - Visibility

    func setVisible(
        _ visible: Bool
    ) {

        entity?.isEnabled =
            visible
    }


    // MARK: - Set Pose

    func setPose(
        _ pose: RobotPose
    ) {

        self.pose =
            pose

        applyPose()
    }


    // MARK: - Drive Simulation

    func drive(
        _ command:
            RobotDriveCommand
    ) {

        // ----------------------------------------------
        // Update lightweight simulation state
        // ----------------------------------------------

        pose.rotation -=
            Float(
                command.rotation
            )
            * movementUpdateInterval


        // Robot-relative movement.

        let forward =
            Float(
                command.forward
            )
            * movementUpdateInterval

        let sideways =
            -Float(
                command.sideways
            )
            * movementUpdateInterval


        let sinRotation =
            sin(
                pose.rotation
            )

        let cosRotation =
            cos(
                pose.rotation
            )


        pose.position.x +=
            sideways
                * cosRotation
            +
            forward
                * -sinRotation


        pose.position.z +=
            forward
                * -cosRotation
            -
            sideways
                * sinRotation


        // ----------------------------------------------
        // Nothing else required if AR robot is hidden.
        // ----------------------------------------------

        guard entity != nil
        else {
            return
        }


        applyPose()

        animateWheels(
            command
        )
    }


    // MARK: - Synchronized Drive Visuals

    func animate(
        _ command:
            RobotDriveCommand
    ) {

        // In synchronized mode the position comes
        // from AprilTag localization.
        //
        // Therefore this function only animates
        // the visible representation.

        guard entity != nil
        else {
            return
        }

        animateWheels(
            command
        )
    }


    // MARK: - Stop

    func stop() {

        // No persistent visual state is required.
        //
        // The wheels simply stop receiving
        // additional rotation.
    }


    // MARK: - Lights

    func setLightMode(
        _ mode:
            Eduard.LightMode
    ) {

        guard entity != nil
        else {
            return
        }


        shitLightEffectTask?
            .cancel()

        oilLightEffectTask?
            .cancel()

        switch mode {

        case .slowBlinking:
            startBlinkingLights(
                color:
                    .red,

                duration:
                    nil
            )

        case .flashLeft:
            applyDefaultLightMaterials()
            applyLightMaterial(
                to:
                    frontLeftLight,

                color:
                    .orange
            )
            applyLightMaterial(
                to:
                    backLeftLight,

                color:
                    .orange
            )

        case .flashRight:
            applyDefaultLightMaterials()
            applyLightMaterial(
                to:
                    frontRightLight,

                color:
                    .orange
            )
            applyLightMaterial(
                to:
                    backRightLight,

                color:
                    .orange
            )

        case .dimmed,
             .enabled,
             .loading,
             .beam,
             .rotation,
             .running,
             .solid,
             .rainbow,
             .rainbowSolid:
            applyDefaultLightMaterials()
        }
    }


    func startShitEffect(
        duration: TimeInterval
    ) {

        shitLightEffectTask?
            .cancel()

        applyAllLightMaterials(
            color:
                UIColor(
                    red:
                        117 / 255,

                    green:
                        76 / 255,

                    blue:
                        41 / 255,

                    alpha:
                        1
                )
        )

        shitLightEffectTask =
            Task { @MainActor [weak self] in

                try? await Task.sleep(
                    for:
                        .seconds(
                            duration
                        )
                )

                guard Task.isCancelled == false,
                      let self
                else {
                    return
                }

                self.applyDefaultLightMaterials()
            }
    }


    func startOilEffect(
        duration: TimeInterval
    ) {

        startBlinkingLights(
            color:
                .red,

            duration:
                duration
        )
    }


    // MARK: - Oil Effect

    func startOilSpinEffect(
        duration: TimeInterval = 5.0
    ) {

        oilSpinTask?
            .cancel()

        oilSpinTask =
            Task { @MainActor [weak self] in

                guard let self
                else {
                    return
                }

                let updateInterval:
                    Float = 0.02

                // About one full 360 degree spin.
                let rotationSpeed:
                    Float = 4.0

                let endTime =
                    Date()
                    .addingTimeInterval(
                        duration
                    )

                while Date() < endTime {

                    guard Task.isCancelled == false
                    else {
                        return
                    }

                    self.pose.rotation +=
                        rotationSpeed
                        * updateInterval

                    self.applyPose()

                    try? await Task.sleep(
                        for:
                            .seconds(
                                Double(
                                    updateInterval
                                )
                            )
                    )
                }
            }
    }


    private func startBlinkingLights(
        color: UIColor,
        duration: TimeInterval?
    ) {

        oilLightEffectTask?
            .cancel()

        oilLightEffectTask =
            Task { @MainActor [weak self] in

                let endDate =
                    duration.map {
                        Date()
                            .addingTimeInterval(
                                $0
                            )
                    }

                var lightsOn =
                    true

                while endDate.map({ Date() < $0 }) ?? true {

                    guard Task.isCancelled == false,
                          let self
                    else {
                        return
                    }

                    self.applyAllLightMaterials(
                        color:
                            lightsOn
                            ? color
                            : .black
                    )

                    lightsOn
                        .toggle()

                    try? await Task.sleep(
                        for:
                            .seconds(
                                0.35
                            )
                    )
                }

                guard Task.isCancelled == false,
                      let self
                else {
                    return
                }

                self.applyDefaultLightMaterials()
            }
    }


    private func applyDefaultLightMaterials() {

        applyLightMaterial(
            to:
                frontLeftLight,

            color:
                .white
        )

        applyLightMaterial(
            to:
                frontRightLight,

            color:
                .white
        )

        applyLightMaterial(
            to:
                backLeftLight,

            color:
                .red
        )

        applyLightMaterial(
            to:
                backRightLight,

            color:
                .red
        )
    }


    private func applyAllLightMaterials(
        color: UIColor
    ) {

        [
            frontLeftLight,
            frontRightLight,
            backLeftLight,
            backRightLight
        ].forEach {

            applyLightMaterial(
                to:
                    $0,

                color:
                    color
            )
        }
    }


    private func applyLightMaterial(
        to entity: Entity?,
        color: UIColor
    ) {

        guard let entity
        else {
            return
        }


        let material =
            SimpleMaterial(
                color:
                    color,

                isMetallic:
                    false
            )


        applyMaterial(
            material,
            to:
                entity
        )
    }


    private func applyMaterial(
        _ material: RealityKit.Material,
        to entity: Entity
    ) {

        if var modelComponent =
            entity.components[ModelComponent.self] {

            modelComponent.materials =
                [
                    material
                ]

            entity.components.set(
                modelComponent
            )
        }


        for child in entity.children {

            applyMaterial(
                material,
                to:
                    child
            )
        }
    }


    private func printEntityLookupStatus() {

        print(
            "# EDUARD MODEL ENTITIES | wheels FL \(frontLeftWheel != nil) | FR \(frontRightWheel != nil) | BL \(backLeftWheel != nil) | BR \(backRightWheel != nil)"
        )

        print(
            "# EDUARD MODEL ENTITIES | lights FL \(frontLeftLight != nil) | FR \(frontRightLight != nil) | BL \(backLeftLight != nil) | BR \(backRightLight != nil)"
        )
    }


    // MARK: - Apply Pose

    private func applyPose() {
        guard let entity else {
            return
        }

        // Logical heading of Eduard.
        let rotation =
            simd_quatf(
                angle: pose.rotation,
                axis: SIMD3<Float>(0, 1, 0)
            )

        // Robot forward direction.
        // Your drive() implementation uses local -Z as forward.
        let forward =
            rotation.act(
                SIMD3<Float>(
                    0,
                    0,
                    -1
                )
            )

        // Place visible model relative to the logical robot pose.
        entity.position =
            pose.position
            + forward
            * modelForwardOffset

        // Rotate around vertical Y axis.
        entity.orientation =
            rotation
    }


    // MARK: - Wheel Animation

    private func animateWheels(
        _ command:
            RobotDriveCommand
    ) {

        let forward =
            Float(
                command.forward
            )

        let sideways =
            Float(
                command.sideways
            )

        let rotation =
            Float(
                command.rotation
            )


        wheelAnimationDebugCounter +=
            1

        if wheelAnimationDebugCounter % 20 == 0 {

            print(
                String(
                    format:
                        "# WHEEL COMMAND | forward %+6.3f | sideways %+6.3f | rotation %+6.3f",
                    forward,
                    sideways,
                    rotation
                )
            )
        }


        // Simple Mecanum wheel mixing.

        let frontLeft =
            forward
            - sideways
            + rotation

        let frontRight =
            forward
            + sideways
            - rotation

        let backLeft =
            forward
            - sideways
            + rotation

        let backRight =
            forward
            + sideways
            - rotation


        if wheelAnimationDebugCounter % 20 == 0 {

            print(
                String(
                    format:
                        "# WHEEL SPEEDS | FL %+6.3f | FR %+6.3f | BL %+6.3f | BR %+6.3f",
                    frontLeft,
                    frontRight,
                    backLeft,
                    backRight
                )
            )
        }


        rotateWheel(
            frontLeftWheel,
            speed:
                frontLeft,
            direction:
                -1
        )

        rotateWheel(
            frontRightWheel,
            speed:
                frontRight,
            direction:
                -1
        )

        rotateWheel(
            backLeftWheel,
            speed:
                backLeft,
            direction:
                1
        )

        rotateWheel(
            backRightWheel,
            speed:
                backRight,
            direction:
                1
        )
    }


    // MARK: - Rotate Wheel

    private func rotateWheel(
        _ wheel: Entity?,
        speed: Float,
        direction: Float
    ) {

        guard let wheel
        else {

            if wheelAnimationDebugCounter % 20 == 0 {

                print(
                    "# WHEEL ENTITY MISSING"
                )
            }

            return
        }


        let rotation =
            simd_quatf(
                angle:
                    speed
                    * direction
                    * wheelRotationSpeed,

                axis:
                    SIMD3<Float>(
                        1,
                        0,
                        0
                    )
            )


        wheel.orientation =
            rotation
            * wheel.orientation
    }
}
