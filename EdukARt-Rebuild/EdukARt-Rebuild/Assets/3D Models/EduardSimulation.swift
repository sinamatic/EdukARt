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


    // MARK: - Settings

    private let movementUpdateInterval:
        Float = 0.01 // change speed of AR Model

    private let wheelRotationSpeed:
        Float = 0.12


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


        // Add RealityKit material changes here
        // using the four stored light entities.
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

        guard let entity
        else {
            return
        }


        entity.position =
            pose.position


        entity.orientation =
            simd_quatf(
                angle:
                    pose.rotation,

                axis:
                    SIMD3<Float>(
                        0,
                        1,
                        0
                    )
            )
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
