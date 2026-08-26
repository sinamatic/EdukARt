//
//  RobotController.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 26.08.26.
//
//  Central controller for the physical and
//  simulated Eduard robots.
//

import Combine
import Foundation


final class RobotController:
    ObservableObject {


    // MARK: - Connection State

    enum ConnectionState:
        Equatable {

        case disconnected
        case connected
        case enabled


        var title: String {

            switch self {

            case .disconnected:
                return "Not connected"

            case .connected:
                return "Connected, not enabled"

            case .enabled:
                return "Enabled"
            }
        }
    }


    // MARK: - Joystick Direction

    enum JoystickDirection {

        case idle

        case forward
        case backward

        case left
        case right

        case forwardLeft
        case forwardRight

        case backwardLeft
        case backwardRight
    }


    // MARK: - Rotation Direction

    enum RotationDirection {

        case left
        case right
    }


    // MARK: - Robots

    let eduard:
        Eduard

    let eduardSimulation:
        EduardSimulation


    // MARK: - Control State

    @Published var controlMode:
        RobotControlMode = .real

    @Published var driveMode:
        RobotDriveMode = .mechanum


    // MARK: - Physical Robot State

    @Published private(set)
    var isConnected =
        false

    @Published private(set)
    var isEnabled =
        false

    @Published private(set)
    var statusMessage =
        "Connect the iPhone to the EduardBlue3 WiFi network first."


    // MARK: - Robot Localization

    @Published private(set)
    var realRobotPose:
        RobotPose?


    // MARK: - Joystick State

    @Published private(set)
    var activeJoystickDirection:
        JoystickDirection = .idle


    private var joystickInput =
        (
            x: 0.0,
            y: 0.0
        )

    private var activeRotationDirection:
        RotationDirection?


    // MARK: - Settings

    private let commandRepeatInterval =
        0.05

    private let joystickDeadZone =
        0.05

    private let diagonalDirectionThreshold =
        0.35

    private let velocityScale =
        1.5

    private let maxAngularSpeed =
        Double.pi


    // MARK: - Timer

    private var commandTimer:
        Timer?


    // MARK: - Connection State

    var connectionState:
        ConnectionState {

        if isEnabled {
            return .enabled
        }

        if isConnected {
            return .connected
        }

        return .disconnected
    }


    // MARK: - Init

    init(
        eduard:
            Eduard = Eduard(),

        eduardSimulation:
            EduardSimulation =
                EduardSimulation()
    ) {

        self.eduard =
            eduard

        self.eduardSimulation =
            eduardSimulation
    }


    deinit {

        commandTimer?
            .invalidate()
    }


    // ======================================================
    // MARK: - Connection
    // ======================================================

    func connect() {

        guard isConnected == false
        else {
            return
        }

        isConnected =
            true

        statusMessage =
            "Connected."
    }

    func disconnect() {

        stopCommandLoop()

        eduard.stop()
        
        eduard.stopLights()

        activeJoystickDirection =
            .idle

        activeRotationDirection =
            nil

        isConnected =
            false

        isEnabled =
            false

        statusMessage =
            "Disconnected."
    }


    // ======================================================
    // MARK: - Enable / Disable
    // ======================================================

    func sendEnable() {

        guard isConnected
        else {

            statusMessage =
                "Confirm the WiFi connection before sending Enable."

            return
        }


        eduard.setEnabled(
            true,
            driveMode:
                driveMode
        )


        isEnabled =
            true

        statusMessage =
            "Enable active."

        startCommandLoop()
    }


    func sendDisable() {

        guard isConnected
        else {
            return
        }


        stopCommandLoop()

        eduard.setEnabled(
            false,
            driveMode:
                driveMode
        )


        isEnabled =
            false

        statusMessage =
            "Disable sent."
    }


    // ======================================================
    // MARK: - Drive Mode
    // ======================================================

    func setDriveMode(
        _ mode:
            RobotDriveMode
    ) {

        guard driveMode != mode
        else {
            return
        }


        driveMode =
            mode

        stopJoystick()


        if isEnabled {

            eduard.setEnabled(
                true,
                driveMode:
                    mode
            )
        }
    }


    // ======================================================
    // MARK: - Joystick
    // ======================================================

    func updateJoystickInput(
        x: Float,
        y: Float
    ) {

        joystickInput =
            normalizedJoystickInput(
                x:
                    Double(x),

                y:
                    Double(y)
            )


        activeJoystickDirection =
            joystickDirection(
                x:
                    joystickInput.x,

                y:
                    joystickInput.y
            )


        sendCurrentCommand()
    }


    func stopJoystick() {

        joystickInput =
            (
                x: 0,
                y: 0
            )

        activeJoystickDirection =
            .idle

        sendCurrentCommand()
    }


    // ======================================================
    // MARK: - Rotation
    // ======================================================

    func startMechanumRotation(
        _ direction:
            RotationDirection
    ) {

        guard driveMode == .mechanum
        else {
            return
        }


        activeRotationDirection =
            direction

        sendCurrentCommand()
    }


    func stopMechanumRotation() {

        activeRotationDirection =
            nil

        sendCurrentCommand()
    }


    // ======================================================
    // MARK: - Lights
    // ======================================================

    func sendLightMode(
        _ mode:
            Eduard.LightMode
    ) {

        switch controlMode {

        case .real:

            guard isConnected
            else {
                return
            }

            eduard.setLightMode(
                mode
            )


        case .simulation:

            eduardSimulation
                .setLightMode(
                    mode
                )


        case .synchronized:

            if isConnected {

                eduard.setLightMode(
                    mode
                )
            }

            // Does nothing when the AR model is hidden.
            eduardSimulation
                .setLightMode(
                    mode
                )
        }
    }


    // ======================================================
    // MARK: - Robot Pose
    // ======================================================

    func updateRealRobotPose(
        _ pose:
            RobotPose
    ) {

        realRobotPose =
            pose


        // Only synchronized mode continuously
        // transfers the measured real pose.

        guard controlMode
                == .synchronized

        else {
            return
        }


        eduardSimulation
            .setPose(
                pose
            )
    }


    // MARK: - Sync Now

    func synchronizeSimulationToEduard() {

        guard let realRobotPose
        else {
            return
        }


        eduardSimulation
            .setPose(
                realRobotPose
            )
    }


    // ======================================================
    // MARK: - Send Command
    // ======================================================

    private func sendCurrentCommand() {

        let command =
            currentDriveCommand()


        switch controlMode {


        // --------------------------------------------------
        // Physical Eduard only
        // --------------------------------------------------

        case .real:

            guard isConnected,
                  isEnabled

            else {
                return
            }


            eduard.drive(
                command
            )


        // --------------------------------------------------
        // Simulation only
        // --------------------------------------------------

        case .simulation:

            eduardSimulation
                .drive(
                    command
                )


        // --------------------------------------------------
        // Physical + synchronized simulation
        // --------------------------------------------------

        case .synchronized:

            guard isConnected,
                  isEnabled

            else {
                return
            }


            eduard.drive(
                command
            )


            // Do NOT move the simulated pose here.
            //
            // Its position comes from AprilTag #0.
            //
            // If the AR model is hidden,
            // animate() immediately returns.

            eduardSimulation
                .animate(
                    command
                )
        }
    }


    // ======================================================
    // MARK: - Drive Command
    // ======================================================

    private func currentDriveCommand()
        -> RobotDriveCommand {


        let magnitude =
            joystickMagnitude


        // ----------------------------------------------
        // Rotation
        // ----------------------------------------------

        let rotation:
            Double


        switch activeRotationDirection {

        case .left:
            rotation =
                maxAngularSpeed

        case .right:
            rotation =
                -maxAngularSpeed

        case nil:

            if driveMode == .offroad {

                rotation =
                    -joystickInput.x
                    * maxAngularSpeed

            } else {

                rotation =
                    0
            }
        }


        // ----------------------------------------------
        // No joystick movement
        // ----------------------------------------------

        guard magnitude
                > joystickDeadZone

        else {

            return RobotDriveCommand(
                forward:
                    0,

                sideways:
                    0,

                rotation:
                    rotation
            )
        }


        // ----------------------------------------------
        // Linear Movement
        // ----------------------------------------------

        let forward =
            -joystickInput.y
            * velocityScale


        let sideways:
            Double


        if driveMode == .mechanum {

            sideways =
                -joystickInput.x
                * velocityScale

        } else {

            sideways =
                0
        }


        return RobotDriveCommand(
            forward:
                forward,

            sideways:
                sideways,

            rotation:
                rotation
        )
    }


    // ======================================================
    // MARK: - Command Loop
    // ======================================================

    private func startCommandLoop() {

        stopCommandLoop()


        commandTimer =
            Timer.scheduledTimer(
                withTimeInterval:
                    commandRepeatInterval,

                repeats:
                    true
            ) { [weak self] _ in

                self?
                    .sendCurrentCommand()
            }
    }


    private func stopCommandLoop() {

        commandTimer?
            .invalidate()

        commandTimer =
            nil
    }


    // ======================================================
    // MARK: - Joystick Helpers
    // ======================================================

    private var joystickMagnitude:
        Double {

        sqrt(
            joystickInput.x
                * joystickInput.x
            +
            joystickInput.y
                * joystickInput.y
        )
    }


    private func normalizedJoystickInput(
        x: Double,
        y: Double
    ) -> (
        x: Double,
        y: Double
    ) {

        let clampedX =
            min(
                max(x, -1),
                1
            )

        let clampedY =
            min(
                max(y, -1),
                1
            )


        let magnitude =
            sqrt(
                clampedX
                    * clampedX
                +
                clampedY
                    * clampedY
            )


        guard magnitude > 1
        else {

            return (
                clampedX,
                clampedY
            )
        }


        return (
            clampedX / magnitude,
            clampedY / magnitude
        )
    }


    private func joystickDirection(
        x: Double,
        y: Double
    ) -> JoystickDirection {

        guard joystickMagnitude
                > joystickDeadZone

        else {
            return .idle
        }


        if y
            < -diagonalDirectionThreshold {

            if x
                < -diagonalDirectionThreshold {

                return .forwardLeft
            }


            if x
                > diagonalDirectionThreshold {

                return .forwardRight
            }


            return .forward
        }


        if y
            > diagonalDirectionThreshold {

            if x
                < -diagonalDirectionThreshold {

                return .backwardLeft
            }


            if x
                > diagonalDirectionThreshold {

                return .backwardRight
            }


            return .backward
        }


        if x
            < -diagonalDirectionThreshold {

            return .left
        }


        if x
            > diagonalDirectionThreshold {

            return .right
        }


        return .idle
    }
}
