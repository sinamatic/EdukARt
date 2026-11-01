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


enum EduardModelAlignment {

    /// Move the visible robot and occluder backward
    /// relative to Eduard's local heading.
    static let backwardOffset:
        Float = 0.13

    /// Negative yaw is a small clockwise/right correction
    /// in the current map coordinate convention.
    static let yawCorrection:
        Float = -.pi / 180
}


final class EduardSimulation {

    // MARK: - Robot State

    private(set) var pose:
        RobotPose = .zero

    private var activeDriveCommand: RobotDriveCommand = .stop
    private var movementTask: Task<Void, Never>?
    private var lastMovementUpdate: Date?

    /// Center of the imported model relative to its authored origin. The USD
    /// model's origin is near the front, so rotating the wrapper directly
    /// otherwise makes Eduard orbit around that point.
    private var visualPivotOffset: SIMD3<Float> = .zero


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

        let bounds = entity.visualBounds(relativeTo: entity)
        visualPivotOffset = SIMD3<Float>(
            bounds.center.x,
            0,
            bounds.center.z
        )
        for child in entity.children {
            child.position -= visualPivotOffset
        }
        


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

        visualPivotOffset = .zero

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

        stopMovement()
    }


    // MARK: - Visibility

    func setVisible(
        _ visible: Bool
    ) {

        entity?.isEnabled =
            visible
    }


    func setOpacity(
        _ opacity: Float
    ) {

        guard let entity else {
            return
        }

        applyOpacity(
            max(0, min(1, opacity)),
            to: entity
        )
    }


    private func applyOpacity(
        _ opacity: Float,
        to entity: Entity
    ) {
        if var modelComponent = entity.components[ModelComponent.self] {
            modelComponent.materials = modelComponent.materials.map { material in
                if var material = material as? PhysicallyBasedMaterial {
                    material.blending = opacity >= 0.999
                        ? .opaque
                        : .transparent(
                            opacity: .init(floatLiteral: opacity)
                        )
                    return material
                }

                if var material = material as? UnlitMaterial {
                    material.blending = opacity >= 0.999
                        ? .opaque
                        : .transparent(
                            opacity: .init(floatLiteral: opacity)
                        )
                    return material
                }

                if var material = material as? CustomMaterial {
                    material.blending = opacity >= 0.999
                        ? .opaque
                        : .transparent(
                            opacity: .init(floatLiteral: opacity)
                        )
                    return material
                }

                return material
            }
            entity.components.set(modelComponent)
        }

        for child in entity.children {
            applyOpacity(opacity, to: child)
        }
    }


    // MARK: - Set Pose

    func setPose(
        _ pose: RobotPose,
        animateMovement: Bool = false
    ) {
        let previousPose = self.pose
        self.pose =
            pose

        applyPose()

        if animateMovement {
            animateWheelsForPoseChange(
                from: previousPose,
                to: pose
            )
        }
    }

    private func animateWheelsForPoseChange(
        from start: RobotPose,
        to end: RobotPose
    ) {
        let dx = end.position.x - start.position.x
        let dz = end.position.z - start.position.z
        let sinHeading = sin(start.rotation)
        let cosHeading = cos(start.rotation)
        let forward = -(dx * sinHeading + dz * cosHeading)
            / movementUpdateInterval
        let sideways = (dx * cosHeading - dz * sinHeading)
            / movementUpdateInterval
        let rotation = -atan2(
            sin(end.rotation - start.rotation),
            cos(end.rotation - start.rotation)
        ) / movementUpdateInterval

        animateWheels(
            RobotDriveCommand(
                forward: Double(forward),
                sideways: Double(sideways),
                rotation: Double(rotation)
            )
        )
    }


    // MARK: - Drive Simulation

    func drive(
        _ command:
            RobotDriveCommand
    ) {
        updateMovement()
        activeDriveCommand = command
        lastMovementUpdate = Date()

        guard hasMovement(command) else {
            stopMovement()
            return
        }

        guard movementTask == nil else {
            return
        }

        movementTask = Task { @MainActor [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(1.0 / 60.0))
                guard Task.isCancelled == false else {
                    return
                }
                self?.updateMovement()
            }
        }
    }

    private func updateMovement() {
        guard let lastMovementUpdate else {
            return
        }

        let elapsed = min(Float(Date().timeIntervalSince(lastMovementUpdate)), 0.1)
        self.lastMovementUpdate = Date()
        pose.rotation -= Float(activeDriveCommand.rotation) * elapsed

        let forward = Float(activeDriveCommand.forward) * elapsed
        let sideways = -Float(activeDriveCommand.sideways) * elapsed
        let sinRotation = sin(pose.rotation)
        let cosRotation = cos(pose.rotation)

        pose.position.x += sideways * cosRotation - forward * sinRotation
        pose.position.z += -forward * cosRotation - sideways * sinRotation
        applyPose()

        let wheelScale = elapsed / movementUpdateInterval
        animateWheels(
            RobotDriveCommand(
                forward: activeDriveCommand.forward * Double(wheelScale),
                sideways: activeDriveCommand.sideways * Double(wheelScale),
                rotation: activeDriveCommand.rotation * Double(wheelScale)
            )
        )
    }

    private func hasMovement(_ command: RobotDriveCommand) -> Bool {
        abs(command.forward) > 0.0001
            || abs(command.sideways) > 0.0001
            || abs(command.rotation) > 0.0001
    }

    private func stopMovement() {
        movementTask?.cancel()
        movementTask = nil
        activeDriveCommand = .stop
        lastMovementUpdate = nil
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

        stopMovement()

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

    func blinkLights(
        color: UIColor,
        duration: TimeInterval = 1.2
    ) {
        startBlinkingLights(
            color: color,
            duration: duration
        )
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
                angle:
                    pose.rotation
                    + EduardModelAlignment.yawCorrection,

                axis: SIMD3<Float>(0, 1, 0)
            )

        // The imported child has already been centered around this wrapper.
        // Keeping the wrapper exactly at the logical pose makes both the
        // driven AR model and every ghost rotate around the same center.
        entity.position = pose.position

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
                -1
        )

        rotateWheel(
            backRightWheel,
            speed:
                backRight,
            direction:
                -1
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


final class EduardOccluder {

    private(set) var entity:
        Entity?

    private var visualPivotOffset: SIMD3<Float> = .zero


    func show(
        entity: Entity
    ) {

        self.entity =
            entity

        let bounds = entity.visualBounds(relativeTo: entity)
        visualPivotOffset = SIMD3<Float>(
            bounds.center.x,
            0,
            bounds.center.z
        )
        for child in entity.children {
            child.position -= visualPivotOffset
        }

        // MARK - Occluder Material is invisible
        applyOcclusionMaterial(
            to:
                entity
        )

        setEnabled(
            false
        )
    }


    func setEnabled(
        _ enabled: Bool
    ) {

        entity?.isEnabled =
            enabled
    }


    func setPose(
        _ pose:
            RobotPose
    ) {

        guard let entity
        else {
            return
        }

        let rotation =
            simd_quatf(
                angle:
                    pose.rotation
                    + EduardModelAlignment.yawCorrection,

                axis:
                    SIMD3<Float>(
                        0,
                        1,
                        0
                    )
            )

        entity.position = pose.position

        entity.orientation =
            rotation
    }
    
    
    private func applyOcclusionMaterial(
        to entity: Entity
    ) {
        if var modelComponent =
            entity.components[
                ModelComponent.self
            ] {

            modelComponent.materials =
                modelComponent.materials.map { _ in
                    OcclusionMaterial()
                }

            entity.components.set(
                modelComponent
            )
        }

        for child in entity.children {
            applyOcclusionMaterial(
                to:
                    child
            )
        }
    }


    private func applyDebugMaterial(
        to entity:
            Entity
    ) {

        if var model =
            entity.components[
                ModelComponent.self
            ] {

            model.materials =
                model.materials.map { _ in
                    SimpleMaterial(
                        color:
                            UIColor(
                                red:
                                    1,
                                green:
                                    0,
                                blue:
                                    0,
                                alpha:
                                    0.8
                            ),
                        isMetallic:
                            false
                    )
                }

            entity.components.set(
                model
            )
        }

        for child in entity.children {

            applyDebugMaterial(
                to:
                    child
            )
        }
    }
}
