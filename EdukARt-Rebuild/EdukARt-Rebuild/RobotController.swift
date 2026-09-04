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


    // MARK: - Robots

    let eduard:
        Eduard

    let eduardSimulation:
        EduardSimulation

    let eduardOccluder:
        EduardOccluder


    // MARK: - Control State

    @Published var controlMode:
        RobotControlMode = .real

    @Published var driveMode:
        RobotDriveMode = .mechanum


    // MARK: - AR Synchronization

    @Published var isLiveSyncEnabled =
        false


    // MARK: - AR Robot Visibility

    @Published private(set)
    var isSimulationVisible =
        false


    // MARK: - Physical Robot State

    @Published private(set)
    var isConnected =
        false

    @Published private(set)
    var isWifiReachable =
        false

    @Published private(set)
    var isEnabled =
        false

    @Published private(set)
    var statusMessage =
        "Ready to enable Eduard."


    // MARK: - Robot Localization

    @Published private(set)
    var realRobotPose:
        RobotPose?


    // MARK: - Joystick State

    @Published private(set)
    var activeJoystickDirection:
        JoystickDirection = .idle


    // ======================================================
    // MARK: - Gameplay Drive Override
    // ======================================================

    @Published private(set)
    var isGameplayDriveLocked =
        false


    private var gameplayDriveCommand:
        RobotDriveCommand?


    private var gameplayDriveTask:
        Task<Void, Never>?

    private var gameplaySpeedMultiplier:
        Double = 1.0

    private var pendingShitSpeedReductions:
        Int = 0


    private var joystickInput =
        (
            x: 0.0,
            y: 0.0
        )

    private var mechanumRotationInput =
        0.0


    // MARK: - Settings

    private let commandRepeatInterval =
        0.05

    private let connectionCheckInterval =
        2.0

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

    private var connectionTimer:
        Timer?

    private var oilEffectTask:
        Task<Void, Never>?

    private var treeLightEffectTask:
        Task<Void, Never>?

    private var isGameplayInputLocked =
        false

    private var isCheckingConnection =
        false


    // MARK: - Connection State

    var connectionState:
        ConnectionState {

        if isEnabled {
            return .enabled
        }

        if isWifiReachable {
            return .connected
        }

        return .disconnected
    }


    // MARK: - Effective Control Mode

    private var effectiveControlMode:
        RobotControlMode {

        // If the physical robot cannot receive commands,
        // automatically fall back to the AR simulation.
        if isConnected == false
            || isEnabled == false {

            return .simulation
        }

        return controlMode
    }


    // MARK: - Init

    init(
        eduard:
            Eduard = Eduard(),

        eduardSimulation:
            EduardSimulation =
                EduardSimulation(),

        eduardOccluder:
            EduardOccluder =
                EduardOccluder()
    ) {

        self.eduard =
            eduard

        self.eduardSimulation =
            eduardSimulation

        self.eduardOccluder =
            eduardOccluder

        startConnectionChecks()
    }


    deinit {

        commandTimer?
            .invalidate()

        connectionTimer?
            .invalidate()

        oilEffectTask?
            .cancel()

        treeLightEffectTask?
            .cancel()

        gameplayDriveTask?
            .cancel()
    }


    // ======================================================
    // MARK: - Connection
    // ======================================================

    func connect() {

        eduard.reconnect()

        isConnected =
            true

        isWifiReachable =
            true

        statusMessage =
            "Ready for Eduard."
    }


    func reconnect() {

        connect()
    }

    func checkConnection() {
        guard isCheckingConnection == false else { return }
        isCheckingConnection =
            true

        eduard.checkConnection { [weak self] isConnected in
            DispatchQueue.main.async {
                self?.isCheckingConnection =
                    false

                self?.updateConnectionState(isConnected)
            }
        }
    }

    func disconnect() {

        stopCommandLoop()

        eduard.stop()
        
        eduard.stopLights()

        activeJoystickDirection =
            .idle

        mechanumRotationInput =
            0

        isConnected =
            false

        isWifiReachable =
            false

        isEnabled =
            false

        statusMessage =
            "Disconnected."
    }

    private func updateConnectionState(_ connected: Bool) {
        let wasReachable =
            isWifiReachable

        isWifiReachable =
            connected

        print(
            "# WIFI PING \(connected) | IS ENABLED \(isEnabled)"
        )

        if connected != wasReachable || connected == false {
            statusMessage =
                connected
                ? "Eduard WiFi reachable."
                : "Eduard WiFi not reachable."
        }
    }


    // ======================================================
    // MARK: - Enable / Disable
    // ======================================================

    func toggleEnabled() {

        if isEnabled {
            sendDisable()
        } else {
            sendEnable()
        }
    }
    
    func sendEnable() {

        // Recreate the UDP connection.
        //
        // This is especially important if the user
        // opened WiFi Settings and connected to Eduard
        // after the app had already been started.

        eduard.reconnect()


        eduard.setEnabled(
            true,
            driveMode:
                driveMode
        )


        isConnected =
            true

        isWifiReachable =
            true

        isEnabled =
            true


        statusMessage =
            "Enable active."


        startCommandLoop()
    }


    func sendDisable() {
        stopJoystick()
        stopMechanumRotation()
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

        guard isGameplayInputLocked == false,
              isGameplayDriveLocked == false
        else {
            return
        }

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


    func setGameplayInputLocked(
        _ isLocked:
            Bool
    ) {

        isGameplayInputLocked =
            isLocked

        if isLocked {

            joystickInput =
                (
                    x: 0,
                    y: 0
                )

            activeJoystickDirection =
                .idle

            mechanumRotationInput =
                0

            sendCurrentCommand()
        }
    }


    func resetGameplayEffects() {

        gameplayDriveTask?
            .cancel()

        gameplayDriveTask =
            nil

        gameplayDriveCommand =
            nil

        isGameplayDriveLocked =
            false

        gameplaySpeedMultiplier =
            1.0

        pendingShitSpeedReductions =
            0

        joystickInput =
            (
                x: 0,
                y: 0
            )

        activeJoystickDirection =
            .idle

        mechanumRotationInput =
            0

        sendCurrentCommand()
    }


    func stopJoystick() {

        guard isGameplayInputLocked == false,
              isGameplayDriveLocked == false
        else {
            return
        }

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

    func updateMechanumRotationInput(
        x: Float
    ) {

        guard isGameplayInputLocked == false,
              isGameplayDriveLocked == false
        else {
            return
        }

        guard driveMode == .mechanum
        else {
            return
        }


        let input =
            Double(x)

        mechanumRotationInput =
            abs(input) < joystickDeadZone
            ? 0
            : min(
                max(input, -1),
                1
            )

        sendCurrentCommand()
    }

    func stopMechanumRotation() {

        guard isGameplayInputLocked == false,
              isGameplayDriveLocked == false
        else {
            return
        }

        mechanumRotationInput =
            0

        sendCurrentCommand()
    }


    // ======================================================
    // MARK: - Lights
    // ======================================================

    func sendLightMode(
        _ mode:
            Eduard.LightMode
    ) {

        switch effectiveControlMode {

        case .real:

            eduard.setLightMode(
                mode
            )


        case .simulation:

            eduardSimulation
                .setLightMode(
                    mode
                )


        case .synchronized:

            eduard.setLightMode(
                mode
            )

            // Does nothing when the AR model is hidden.
            eduardSimulation
                .setLightMode(
                    mode
                )
        }
    }


    func startShitEffect(
        duration:
            TimeInterval
    ) {

        pendingShitSpeedReductions +=
            1

        guard isGameplayDriveLocked == false
        else {
            return
        }


        gameplayDriveTask?
            .cancel()


        gameplayDriveTask =
            Task { @MainActor [weak self] in

                guard let self
                else {
                    return
                }


                isGameplayDriveLocked =
                    true


                joystickInput =
                    (
                        x: 0,
                        y: 0
                    )

                activeJoystickDirection =
                    .idle

                mechanumRotationInput =
                    0


                sendLightMode(
                    .rotation
                )

                eduard.setAllLightsColor(
                    red:
                        255,
                    green:
                        100,
                    blue:
                        0
                )


                let diagonalComponent =
                    velocityScale
                    * 0.10
                    / sqrt(2.0)

                let diagonalLeft =
                    RobotDriveCommand(
                        forward:
                            diagonalComponent,
                        sideways:
                            diagonalComponent,
                        rotation:
                            0
                    )

                let diagonalRight =
                    RobotDriveCommand(
                        forward:
                            diagonalComponent,
                        sideways:
                            -diagonalComponent,
                        rotation:
                            0
                    )


                let commands =
                    [
                        diagonalLeft,
                        diagonalRight,
                        diagonalLeft,
                        diagonalRight
                    ]

                let segmentDuration =
                    duration
                    / Double(
                        commands.count
                    )


                for command in commands {

                    gameplayDriveCommand =
                        command

                    sendCurrentCommand()

                    try? await Task.sleep(
                        for:
                            .seconds(
                                segmentDuration
                            )
                    )

                    guard Task.isCancelled == false
                    else {

                        finishShitEffect(
                            reduceSpeed:
                                false
                        )
                        return
                    }
                }


                finishShitEffect(
                    reduceSpeed:
                        true
                )
            }
    }


    private func finishShitEffect(
        reduceSpeed:
            Bool
    ) {

        gameplayDriveCommand =
            .stop

        sendCurrentCommand()


        gameplayDriveCommand =
            nil

        if reduceSpeed {

            gameplaySpeedMultiplier =
                max(
                    0,
                    gameplaySpeedMultiplier
                    - (
                        0.10
                        * Double(
                            pendingShitSpeedReductions
                        )
                    )
                )

            pendingShitSpeedReductions =
                0

            sendLightMode(
                .dimmed
            )
        } else {

            pendingShitSpeedReductions =
                0
        }

        isGameplayDriveLocked =
            false

        activeJoystickDirection =
            .idle

        joystickInput =
            (
                x: 0,
                y: 0
            )

        mechanumRotationInput =
            0

        gameplayDriveTask =
            nil
    }


    func startOilEffect(
        duration: TimeInterval
    ) {

        oilEffectTask?
            .cancel()

        eduardSimulation.startOilEffect(
            duration:
                duration
        )

        isGameplayInputLocked =
            true

        joystickInput =
            (
                x: 0,
                y: 0
            )

        activeJoystickDirection =
            .idle

        mechanumRotationInput =
            0

        sendCurrentCommand()

        eduardSimulation.startOilSpinEffect(
            duration:
                duration
        )

        mechanumRotationInput =
            1

        eduard.setAllLightsColor(
            red:
                255,

            green:
                0,

            blue:
                0
        )

        eduard.setLightMode(
            .slowBlinking
        )

        sendCurrentCommand()

        print(
            "# OIL EFFECT | rotating"
        )


        oilEffectTask =
            Task { [weak self] in

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


                self.mechanumRotationInput =
                    0

                self.isGameplayInputLocked =
                    false

                self.sendCurrentCommand()

                self.eduard.setLightMode(
                    .enabled
                )
            }
    }


    func startTreeEffect(
        duration: TimeInterval
    ) {

        treeLightEffectTask?
            .cancel()

        let previousLightMode =
            eduard.activeLightMode

        let previousAllLightsColor =
            eduard.activeAllLightsColor

        eduard.setAllLightsColor(
            red:
                0,

            green:
                255,

            blue:
                0
        )

        eduard.setLightMode(
            .solid
        )

        print(
            "# TREE LIGHTS | physical Eduard green"
        )


        treeLightEffectTask =
            Task { [weak self] in

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

                self.eduard.setAllLightsColor(
                    red:
                        previousAllLightsColor.red,

                    green:
                        previousAllLightsColor.green,

                    blue:
                        previousAllLightsColor.blue
                )

                self.eduard.setLightMode(
                    previousLightMode
                )
            }
    }

    // MARK: - Place Simulation at Map Reference

    func placeSimulationAtReference() {

        eduardSimulation.setPose(
            .zero
        )
    }


    func toggleSimulationVisibility() {

        isSimulationVisible.toggle()

        eduardSimulation.setVisible(
            isSimulationVisible
        )
    }


    // MARK: - Real Robot Pose

    func updateRealRobotPose(
        _ pose:
            RobotPose
    ) {

        // Always store the current physical pose.
        realRobotPose =
            pose

        eduardOccluder
            .setEnabled(
                true
            )

        eduardOccluder
            .setPose(
                pose
            )


        // Continuously transfer the physical pose
        // only when Live Sync is enabled.
        guard isLiveSyncEnabled
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
            gameplayDriveCommand
            ?? currentDriveCommand()


        switch effectiveControlMode {

        // --------------------------------------------------
        // Physical Eduard only
        // --------------------------------------------------

        case .real:

            eduard.drive(
                command
            )


        // --------------------------------------------------
        // Simulation only
        // --------------------------------------------------

        case .simulation:

            eduardSimulation.drive(
                command
            )


        // --------------------------------------------------
        // Physical + synchronized simulation
        // --------------------------------------------------

        case .synchronized:

            eduard.drive(
                command
            )

            // The simulated position is supplied by
            // AprilTag #0 while synchronized.
            // Only animate the wheels here.

            eduardSimulation.animate(
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


        if driveMode == .mechanum {

                rotation =
                    mechanumRotationInput
                    * maxAngularSpeed
                    * gameplaySpeedMultiplier

        } else if driveMode == .offroad {

            rotation =
                -joystickInput.x
                * maxAngularSpeed
                * gameplaySpeedMultiplier

        } else {

            rotation =
                0
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
            * gameplaySpeedMultiplier


        let sideways:
            Double


        if driveMode == .mechanum {

            sideways =
                -joystickInput.x
                * velocityScale
                * gameplaySpeedMultiplier

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


    private func startConnectionChecks() {

        checkConnection()

        connectionTimer =
            Timer.scheduledTimer(
                withTimeInterval:
                    connectionCheckInterval,

                repeats:
                    true
            ) { [weak self] _ in

                self?
                    .checkConnection()
            }
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
