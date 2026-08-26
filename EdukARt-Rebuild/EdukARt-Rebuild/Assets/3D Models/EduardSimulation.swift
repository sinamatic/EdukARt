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


import RealityKit
import simd


final class EduardSimulation {

    // MARK: - Robot State

    private(set) var pose:
        RobotPose = .zero


    // MARK: - AR Representation

    private(set) var entity:
        Entity?


    var isVisible: Bool {
        entity != nil
    }


    // MARK: - Wheels

    private var frontLeftWheel:
        Entity?

    private var frontRightWheel:
        Entity?

    private var backLeftWheel:
        Entity?

    private var backRightWheel:
        Entity?


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
        Float = 0.05


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
                    "wheel-front-left"
            )

        frontRightWheel =
            entity.findEntity(
                named:
                    "wheel-front-right"
            )

        backLeftWheel =
            entity.findEntity(
                named:
                    "wheel-back-left"
            )

        backRightWheel =
            entity.findEntity(
                named:
                    "wheel-back-right"
            )


        // Find light entities once.

        frontLeftLight =
            entity.findEntity(
                named:
                    "chassis-led-front-left"
            )

        frontRightLight =
            entity.findEntity(
                named:
                    "chassis-led-front-right"
            )

        backLeftLight =
            entity.findEntity(
                named:
                    "chassis-led-back-left"
            )

        backRightLight =
            entity.findEntity(
                named:
                    "chassis-led-back.right"
            )


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

        pose.rotation +=
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
            Float(
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
                * sinRotation


        pose.position.z +=
            forward
                * cosRotation
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


        // Simple Mecanum wheel mixing.

        let frontLeft =
            forward
            + sideways
            + rotation

        let frontRight =
            forward
            - sideways
            - rotation

        let backLeft =
            forward
            - sideways
            + rotation

        let backRight =
            forward
            + sideways
            - rotation


        rotateWheel(
            frontLeftWheel,
            speed:
                frontLeft
        )

        rotateWheel(
            frontRightWheel,
            speed:
                frontRight
        )

        rotateWheel(
            backLeftWheel,
            speed:
                backLeft
        )

        rotateWheel(
            backRightWheel,
            speed:
                backRight
        )
    }


    // MARK: - Rotate Wheel

    private func rotateWheel(
        _ wheel: Entity?,
        speed: Float
    ) {

        guard let wheel
        else {
            return
        }


        let rotation =
            simd_quatf(
                angle:
                    speed
                    * movementUpdateInterval,

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
