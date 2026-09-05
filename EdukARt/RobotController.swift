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

    @Published private(set)
    var gameplaySpeedMultiplier:
        Double = 0.80

    private var normalGameplaySpeedMultiplier:
        Double = 0.80

    private var coinBoostEndDate:
        Date?

    private var coinBoostTask:
        Task<Void, Never>?

    private var isMovementCurrentlyBlocked =
        false

    private var obstacleDamageCooldownEndDates:
        [UUID: Date] = [:]

    private var onObstacleDamage:
        ((MapObjectType) -> Void)?

    @Published private(set)
    var isWaterModeActive =
        false

    private var waterStrokeArmed =
        false

    private var waterStrokeTask:
        Task<Void, Never>?

    private var waterPreviousLightMode:
        Eduard.LightMode?

    private var waterPreviousAllLightsColor:
        (red: Int, green: Int, blue: Int)?

    private var blockingObjects:
        [PlacedMapObject] = []

    private var blockingRevealedTreeIDs:
        Set<UUID> = []

    private let collisionManager =
        CollisionManager()


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

    private let waterStrokeDistance:
        Double = 0.05

    private let waterStrokeSpeed:
        Double = 0.30

    private let baseGameplaySpeedMultiplier:
        Double = 0.80

    private let coinBoostGameplaySpeedMultiplier:
        Double = 0.90

    private let coinBoostDuration:
        TimeInterval = 2.0

    private let obstacleDamageStep:
        Double = 0.10

    private let obstacleDamageCooldownDuration:
        TimeInterval = 10

    private(set) var minSpeedPercent:
        Int = 80

    private(set) var maxSpeedPercent:
        Int = 80


    // MARK: - Timer

    private var commandTimer:
        Timer?

    private var connectionTimer:
        Timer?

    private var oilEffectTask:
        Task<Void, Never>?

    private var treeLightEffectTask:
        Task<Void, Never>?

    private var feedbackLightTask:
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


    var currentSpeedPercent:
        Int {

        Int(
            round(
                gameplaySpeedMultiplier
                * 100
            )
        )
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


    private var currentCollisionPose:
        RobotPose? {

        switch effectiveControlMode {

        case .real,
             .synchronized:
            return realRobotPose

        case .simulation:
            return eduardSimulation.pose
        }
    }


    private var blockingSafetyMargin:
        Float {

        switch effectiveControlMode {

        case .simulation:
            return 0.02

        case .real,
             .synchronized:
            return 0.05
        }
    }


    private var isCoinBoostActive:
        Bool {

        guard let coinBoostEndDate
        else {
            return false
        }

        return Date() < coinBoostEndDate
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

        feedbackLightTask?
            .cancel()

        gameplayDriveTask?
            .cancel()

        coinBoostTask?
            .cancel()

        waterStrokeTask?
            .cancel()
    }


    // ======================================================
    // MARK: - Gameplay Speed
    // ======================================================

    func setObstacleDamageHandler(
        _ handler: @escaping (MapObjectType) -> Void
    ) {

        onObstacleDamage =
            handler
    }


    func applyCoinSpeedBoost() {

        let now =
            Date()

        let startDate =
            max(
                coinBoostEndDate ?? now,
                now
            )

        coinBoostEndDate =
            startDate
                .addingTimeInterval(
                    coinBoostDuration
                )

        updateEffectiveGameplaySpeed()
        scheduleCoinBoostEndCheck()
    }


    func repairObstacleDamage() {

        normalGameplaySpeedMultiplier =
            baseGameplaySpeedMultiplier

        updateEffectiveGameplaySpeed()
    }


    private func applyObstacleDamage() {

        normalGameplaySpeedMultiplier =
            max(
                0,
                normalGameplaySpeedMultiplier
                - obstacleDamageStep
            )

        updateEffectiveGameplaySpeed()

        blinkObstacleDamageLights()
    }


    private func canApplyObstacleDamage(
        for objectID:
            UUID
    ) -> Bool {

        guard let cooldownEndDate =
            obstacleDamageCooldownEndDates[
                objectID
            ]
        else {
            return true
        }

        return Date() >= cooldownEndDate
    }


    private func startObstacleDamageCooldown(
        for objectID:
            UUID
    ) {

        obstacleDamageCooldownEndDates[
            objectID
        ] =
            Date()
                .addingTimeInterval(
                    obstacleDamageCooldownDuration
                )
    }


    private func updateEffectiveGameplaySpeed() {

        gameplaySpeedMultiplier =
            isCoinBoostActive
            ? coinBoostGameplaySpeedMultiplier
            : normalGameplaySpeedMultiplier

        let percent =
            currentSpeedPercent

        minSpeedPercent =
            min(
                minSpeedPercent,
                percent
            )

        maxSpeedPercent =
            max(
                maxSpeedPercent,
                percent
            )
    }


    private func scheduleCoinBoostEndCheck() {

        coinBoostTask?
            .cancel()

        guard let coinBoostEndDate
        else {
            return
        }

        let delay =
            max(
                coinBoostEndDate.timeIntervalSinceNow,
                0
            )

        coinBoostTask =
            Task { @MainActor [weak self] in

                try? await Task.sleep(
                    for:
                        .seconds(
                            delay
                        )
                )

                guard let self,
                      Task.isCancelled == false
                else {
                    return
                }

                if self.isCoinBoostActive == false {

                    self.coinBoostEndDate =
                        nil

                    self.updateEffectiveGameplaySpeed()
                }

                self.coinBoostTask =
                    nil
            }
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

        setDisabledLightState()

        statusMessage =
            "Disable sent."
    }


    func resetPhysicalRobot() {

        print(
            "# ROBOT RESET | Start"
        )

        resetGameplayState()

        eduard.reconnect()

        if isConnected {

            eduard.drive(
                .stop
            )

            eduard.setEnabled(
                false,
                driveMode:
                    driveMode
            )

            eduard.setEnabled(
                true,
                driveMode:
                    driveMode
            )

            isEnabled =
                true

            statusMessage =
                "Robot drive reset sent."

            startCommandLoop()
        } else {

            statusMessage =
                "Robot reset prepared. Connect Eduard first."
        }

        print(
            "# ROBOT RESET | Finished"
        )
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

        if isWaterModeActive {

            updateWaterJoystickInput(
                x:
                    x,

                y:
                    y
            )

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

        oilEffectTask?
            .cancel()

        oilEffectTask =
            nil

        treeLightEffectTask?
            .cancel()

        treeLightEffectTask =
            nil

        feedbackLightTask?
            .cancel()

        feedbackLightTask =
            nil

        gameplayDriveTask?
            .cancel()

        gameplayDriveTask =
            nil

        gameplayDriveCommand =
            nil

        coinBoostTask?
            .cancel()

        coinBoostTask =
            nil

        coinBoostEndDate =
            nil

        waterStrokeTask?
            .cancel()

        waterStrokeTask =
            nil

        isWaterModeActive =
            false

        waterStrokeArmed =
            false

        restoreWaterLights()

        setDisabledLightState()

        isGameplayDriveLocked =
            false

        isGameplayInputLocked =
            false

        normalGameplaySpeedMultiplier =
            baseGameplaySpeedMultiplier

        gameplaySpeedMultiplier =
            baseGameplaySpeedMultiplier

        minSpeedPercent =
            currentSpeedPercent

        maxSpeedPercent =
            currentSpeedPercent

        isMovementCurrentlyBlocked =
            false

        obstacleDamageCooldownEndDates
            .removeAll()

        blockingObjects
            .removeAll()

        blockingRevealedTreeIDs
            .removeAll()

        realRobotPose =
            nil

        feedbackLightTask?
            .cancel()

        feedbackLightTask =
            nil

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


    func resetGameplayState() {

        resetGameplayEffects()
    }


    func resetForManualControl() {

        resetGameplayState()
    }


    private func setDisabledLightState() {

        eduard.setLightMode(
            .running
        )

        eduard.setAllLightsColor(
            red:
                140,

            green:
                0,

            blue:
                255
        )
    }


    func updateBlockingObjects(
        _ objects:
            [PlacedMapObject],

        revealedTreeIDs:
            Set<UUID>
    ) {

        blockingObjects =
            objects

        blockingRevealedTreeIDs =
            revealedTreeIDs
    }

    func setWaterMode(
        _ active:
            Bool
    ) {

        guard isWaterModeActive != active
        else {
            return
        }


        isWaterModeActive =
            active

        if active {

            waterPreviousLightMode =
                eduard.activeLightMode

            waterPreviousAllLightsColor =
                eduard.activeAllLightsColor

            eduard.setLightMode(
                .rotation
            )

            eduard.setAllLightsColor(
                red:
                    0,

                green:
                    80,

                blue:
                    255
            )

            gameplayDriveCommand =
                .stop

            sendCurrentCommand()

            gameplayDriveCommand =
                nil

            waterStrokeArmed =
                false

        } else {

            waterStrokeTask?
                .cancel()

            waterStrokeTask =
                nil

            waterStrokeArmed =
                false

            restoreWaterLights()
        }
    }


    private func restoreWaterLights() {

        if let color =
            waterPreviousAllLightsColor {

            eduard.setAllLightsColor(
                red:
                    color.red,

                green:
                    color.green,

                blue:
                    color.blue
            )
        }

        if let mode =
            waterPreviousLightMode {

            eduard.setLightMode(
                mode
            )
        }

        waterPreviousLightMode =
            nil

        waterPreviousAllLightsColor =
            nil
    }


    private func blinkObstacleDamageLights() {

        blinkAllLights(
            red:
                120,

            green:
                0,

            blue:
                0,

            duration:
                0.8,

            mode:
                .slowBlinking
        )
    }


    func blinkCoinCollectedLights() {

        blinkAllLights(
            red:
                255,

            green:
                220,

            blue:
                0,

            duration:
                0.55,

            mode:
                .rotation
        )
    }


    func blinkItemboxCollectedLights() {

        blinkAllLights(
            red:
                180,

            green:
                80,

            blue:
                255,

            duration:
                0.8,

            mode:
                .rotation
        )
    }


    func blinkEggCollectedLights() {

        blinkAllLights(
            red:
                0,

            green:
                255,

            blue:
                0,

            duration:
                0.55,

            mode:
                .rotation
        )
    }


    func blinkEggsDeliveredLights() {

        blinkAllLights(
            red:
                0,

            green:
                255,

            blue:
                0,

            duration:
                1.5,

            mode:
                .rotation
        )
    }


    func startFinishLightEffect() {

        feedbackLightTask?
            .cancel()

        eduard.setLightMode(
            .rainbow
        )

        feedbackLightTask =
            Task { [weak self] in

                try? await Task.sleep(
                    for:
                        .seconds(
                            10
                        )
                )

                guard Task.isCancelled == false,
                      let self
                else {
                    return
                }

                self.eduard.setLightMode(
                    .enabled
                )

                self.feedbackLightTask =
                    nil
            }
    }


    private func blinkAllLights(
        red: Int,
        green: Int,
        blue: Int,
        duration: TimeInterval,
        mode: Eduard.LightMode
    ) {

        feedbackLightTask?
            .cancel()

        let previousLightMode =
            eduard.activeLightMode

        let previousAllLightsColor =
            eduard.activeAllLightsColor

        eduard.setLightMode(
            mode
        )

        eduard.setAllLightsColor(
            red:
                red,

            green:
                green,

            blue:
                blue
        )

        feedbackLightTask =
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

                self.feedbackLightTask =
                    nil
            }
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

        if isWaterModeActive {

            waterStrokeArmed =
                true
        }

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

        if isWaterModeActive {

            updateWaterRotationInput(
                x:
                    x
            )

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
    // MARK: - Water Movement
    // ======================================================

    private func updateWaterJoystickInput(
        x: Float,
        y: Float
    ) {

        let input =
            normalizedJoystickInput(
                x:
                    Double(x),

                y:
                    Double(y)
            )

        let magnitude =
            sqrt(
                input.x * input.x
                +
                input.y * input.y
            )

        if magnitude <= joystickDeadZone {

            waterStrokeArmed =
                true

            activeJoystickDirection =
                .idle

            return
        }


        activeJoystickDirection =
            joystickDirection(
                x:
                    input.x,

                y:
                    input.y
            )

        guard waterStrokeArmed
        else {
            return
        }


        waterStrokeArmed =
            false

        startWaterStroke(
            x:
                input.x,

            y:
                input.y
        )
    }


    private func startWaterStroke(
        x: Double,
        y: Double
    ) {

        guard waterStrokeTask == nil
        else {
            return
        }


        let magnitude =
            sqrt(
                x * x
                +
                y * y
            )

        guard magnitude > joystickDeadZone
        else {
            return
        }


        let normalizedX =
            x
            / magnitude

        let normalizedY =
            y
            / magnitude

        let forward =
            -normalizedY
            * waterStrokeSpeed

        let sideways =
            driveMode == .mechanum
            ? -normalizedX
                * waterStrokeSpeed
            : 0

        let command =
            RobotDriveCommand(
                forward:
                    forward,

                sideways:
                    sideways,

                rotation:
                    0
            )

        let duration =
            waterStrokeDistance
            / waterStrokeSpeed

        waterStrokeTask =
            Task { @MainActor [weak self] in

                guard let self
                else {
                    return
                }


                gameplayDriveCommand =
                    command

                sendCurrentCommand()

                try? await Task.sleep(
                    for:
                        .seconds(
                            duration
                        )
                )

                guard Task.isCancelled == false
                else {
                    return
                }


                gameplayDriveCommand =
                    .stop

                sendCurrentCommand()

                gameplayDriveCommand =
                    nil

                waterStrokeTask =
                    nil
            }
    }


    private func updateWaterRotationInput(
        x: Float
    ) {

        let input =
            Double(x)

        if abs(input) <= joystickDeadZone {

            waterStrokeArmed =
                true

            mechanumRotationInput =
                0

            return
        }


        guard waterStrokeArmed
        else {
            return
        }


        waterStrokeArmed =
            false

        startWaterRotationStroke(
            x:
                input
        )
    }


    private func startWaterRotationStroke(
        x: Double
    ) {

        guard waterStrokeTask == nil
        else {
            return
        }


        let direction =
            x < 0
            ? -1.0
            : 1.0

        let command =
            RobotDriveCommand(
                forward:
                    0,

                sideways:
                    0,

                rotation:
                    direction
                    * waterStrokeSpeed
                    * 2
            )

        let duration =
            waterStrokeDistance
            / waterStrokeSpeed

        waterStrokeTask =
            Task { @MainActor [weak self] in

                guard let self
                else {
                    return
                }


                gameplayDriveCommand =
                    command

                sendCurrentCommand()

                try? await Task.sleep(
                    for:
                        .seconds(
                            duration
                        )
                )

                guard Task.isCancelled == false
                else {
                    return
                }


                gameplayDriveCommand =
                    .stop

                sendCurrentCommand()

                gameplayDriveCommand =
                    nil

                waterStrokeTask =
                    nil
            }
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
                            switchToDimmedLights:
                                false
                        )
                        return
                    }
                }


                finishShitEffect(
                    switchToDimmedLights:
                        true
                )
            }
    }


    private func finishShitEffect(
        switchToDimmedLights:
            Bool
    ) {

        gameplayDriveCommand =
            .stop

        sendCurrentCommand()


        gameplayDriveCommand =
            nil

        if switchToDimmedLights {

            sendLightMode(
                .dimmed
            )
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
                80,

            blue:
                80
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

        eduard.setLightMode(
            .rotation
        )

        eduard.setAllLightsColor(
            red:
                0,

            green:
                255,

            blue:
                0
        )

        print(
            "# TREE LIGHTS | physical Eduard green rotation"
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

        var command: RobotDriveCommand

        if let gameplayDriveCommand {

            command =
                gameplayDriveCommand

        } else if isWaterModeActive {

            command =
                .stop

        } else {

            command =
                currentDriveCommand()
        }

        if let pose =
            currentCollisionPose {

            if let blockedObject =
                collisionManager.blockingObject(
                    robotPose:
                        pose,

                    command:
                        command,

                    objects:
                        blockingObjects,

                    revealedTreeIDs:
                        blockingRevealedTreeIDs,

                    additionalSafetyMargin:
                        blockingSafetyMargin
                ) {

                if hasLinearMovement(
                    command
                ),
                   isMovementCurrentlyBlocked == false,
                   canApplyObstacleDamage(
                    for:
                        blockedObject.id
                   ) {

                    isMovementCurrentlyBlocked =
                        true

                    startObstacleDamageCooldown(
                        for:
                            blockedObject.id
                    )

                    applyObstacleDamage()

                    onObstacleDamage?(
                        blockedObject.type
                    )
                } else if hasLinearMovement(
                    command
                ) {

                    isMovementCurrentlyBlocked =
                        true
                }

                command =
                    RobotDriveCommand(
                        forward:
                            0,
                        sideways:
                            0,
                        rotation:
                            command.rotation
                    )

            } else {

                isMovementCurrentlyBlocked =
                    false
            }

        } else {

            isMovementCurrentlyBlocked =
                false
        }


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


    private func hasLinearMovement(
        _ command:
            RobotDriveCommand
    ) -> Bool {

        abs(
            command.forward
        )
        > 0.001
        ||
        abs(
            command.sideways
        )
        > 0.001
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
