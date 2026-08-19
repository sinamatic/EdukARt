//
//  EduardRemoteControlController.swift
//  EdukARt
//
//  - Verwaltet den Remote-Control-Zustand in der App.
//  - Sendet Enable-, Stop- und Joystick-Fahrbefehle fuer Eduard.
//  - Wiederholt Fahrbefehle per Timer, solange eine Richtung aktiv ist.

import Combine
import Foundation

final class RobotController: ObservableObject {
    
    enum ConnectionState: Equatable {
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
    
    enum DriveMode: String, CaseIterable, Identifiable {
        case mechanum = "Mechanum"
        case offroad = "Offroad"

        private static let mechanumKinematicValue = 2.0
        private static let offroadKinematicValue = 1.0

        var id: String {
            rawValue
        }

        var driveKinematicValue: Double {
            switch self {
            case .mechanum:
                return Self.mechanumKinematicValue
            case .offroad:
                return Self.offroadKinematicValue
            }
        }
    }

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

    enum RotationDirection {
        case left
        case right
    }

    @Published private(set) var isConnected = false
    
    @Published private(set) var isEnabled = false
    @Published var isSimulationVisible = false
    
    @Published private(set) var activeJoystickDirection: JoystickDirection = .idle
    @Published var driveMode: DriveMode = .mechanum
    @Published private(set) var statusMessage = "Connect the iPhone to the EduardBlue3 WiFi network first."

    let lightController: LightController
    private let eduardCommandTransport: RobotCommandTransport
    private let simulationCommandTransport: RobotCommandTransport
    private var activeCommandTransport: RobotCommandTransport

    var connectionState: ConnectionState {
        if isEnabled {
            return .enabled
        }

        if isConnected {
            return .connected
        }

        return .disconnected
    }

    let transport: EduardROSCommandTransport

    private let setModeService = "set_mode"
    private let commandRepeatInterval = 0.05
    private let joystickDeadZone = 0.05
    private let diagonalDirectionThreshold = 0.35
    private let virtualJoystickVelocityScale = 1.5
    private let maxAngularSpeed = Double.pi
    private let stoppedVelocity = 0.0
    private let remoteControlledModeValue = 2.0
    private let disabledModeValue = 0.0
    private let featureModeValue = 0.0
    private let enableFeatureValue = 0.0
    private let disableFeatureValue = 1.0
    private let joystickMinimumInput = -1.0
    private let joystickMaximumInput = 1.0

    private var commandTimer: Timer?
    private var joystickInput = (x: 0.0, y: 0.0)
    private var activeRotationDirection: RotationDirection?

    init(
        transport: EduardROSCommandTransport = EduardWiFiCommandTransport(),
        simulationCommandTransport: RobotCommandTransport
    ) {
        self.transport = transport
        eduardCommandTransport = EduardRobotCommandTransport(transport: transport)
        self.simulationCommandTransport = simulationCommandTransport
        activeCommandTransport = simulationCommandTransport
        lightController = LightController(transport: transport)
    }

    deinit {
        commandTimer?.invalidate()
    }

    func connect() {
        guard isConnected == false else {
            return
        }

        isConnected = true
        statusMessage = "Sending to \(transport.targetHost):\(transport.targetPort)."
    }

    func disconnect() {
        commandTimer?.invalidate()
        commandTimer = nil
        lightController.stop()
        activeJoystickDirection = .idle
        activeRotationDirection = nil
        isConnected = false
        isEnabled = false
        useSimulationTransport()
        statusMessage = "Disconnected. Connect the iPhone to EduardBlue3 and try again."
    }

    func sendDisable() {
        guard isConnected else {
            statusMessage = "No active connection to Eduard."
            return
        }

        commandTimer?.invalidate()
        commandTimer = nil
        activeJoystickDirection = .idle
        activeRotationDirection = nil
        sendStopCommand()
        sendDisabledMode()
        isEnabled = false
        useSimulationTransport()
        statusMessage = "Disable sent. The connection remains active."
    }

    func sendEnable() {
        isConnected = true
        simulationCommandTransport.stop()
        transport.reconnect()
        sendRemoteControlledMode()
        isEnabled = true
        useEduardTransport()
        sendStopCommand()
        statusMessage = "Enable active. \(driveMode.rawValue) mode ready."
        startCommandLoop()
    }

    func setDriveMode(_ mode: DriveMode) {
        guard driveMode != mode else {
            return
        }

        driveMode = mode
        activeJoystickDirection = .idle
        activeRotationDirection = nil
        sendStopCommand()

    }

    func sendLightMode(_ mode: LightController.StandardMode) {

        guard isConnected else {
            statusMessage = "Confirm the WiFi connection before changing lights."
            return
        }

        lightController.send(mode)
        statusMessage = "Light mode: \(mode.title)."
    }

    func updateJoystickInput(x: Float, y: Float) {
        joystickInput = normalizedJoystickInput(x: Double(x), y: Double(y))

        let direction = joystickDirection(x: joystickInput.x, y: joystickInput.y)
        updateJoystickDirection(direction)
    }

    func stopJoystick() {
        joystickInput = (x: stoppedVelocity, y: stoppedVelocity)
        updateJoystickDirection(.idle)
    }

    func startMechanumRotation(_ direction: RotationDirection) {
        guard driveMode == .mechanum else {
            activeRotationDirection = nil
            sendStopCommand()
            return
        }

        activeRotationDirection = direction
        sendCommand(for: activeJoystickDirection)
        statusMessage = rotationStatusMessage
    }

    func stopMechanumRotation() {
        activeRotationDirection = nil
        sendCommand(for: activeJoystickDirection)
    }

    private func updateJoystickDirection(_ direction: JoystickDirection) {
        guard activeJoystickDirection != direction else {
            sendCommand(for: direction)
            return
        }

        activeJoystickDirection = direction

        sendCommand(for: direction)
    }

    private func sendCommand(for direction: JoystickDirection) {
        switch direction {
        case .idle:
            if activeRotationDirection == nil {
                sendStopCommand()
                statusMessage = "Joystick neutral."
            } else {
                sendJoystickDriveCommand()
                statusMessage = rotationStatusMessage
            }
        case .forward:
            sendJoystickDriveCommand()
            statusMessage = "\(driveMode.rawValue): forward."
        case .backward:
            sendJoystickDriveCommand()
            statusMessage = "\(driveMode.rawValue): backward."
        case .left:
            sendJoystickDriveCommand()
            statusMessage = "\(driveMode.rawValue): left."
        case .right:
            sendJoystickDriveCommand()
            statusMessage = "\(driveMode.rawValue): right."
        case .forwardLeft:
            sendJoystickDriveCommand()
            statusMessage = "\(driveMode.rawValue): forward left."
        case .forwardRight:
            sendJoystickDriveCommand()
            statusMessage = "\(driveMode.rawValue): forward right."
        case .backwardLeft:
            sendJoystickDriveCommand()
            statusMessage = "\(driveMode.rawValue): backward left."
        case .backwardRight:
            sendJoystickDriveCommand()
            statusMessage = "\(driveMode.rawValue): backward right."
        }
    }

    private func startCommandLoop() {
        commandTimer?.invalidate()
        let timer = Timer(timeInterval: commandRepeatInterval, repeats: true) { [weak self] _ in
            guard let self, self.isConnected, self.isEnabled else {
                return
            }

            self.sendCommand(for: self.activeJoystickDirection)
        }

        commandTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func useEduardTransport() {
        simulationCommandTransport.stop()
        activeCommandTransport = eduardCommandTransport
    }

    private func useSimulationTransport() {
        eduardCommandTransport.stop()
        activeCommandTransport = simulationCommandTransport
    }

    private func joystickDirection(x: Double, y: Double) -> JoystickDirection {
        guard joystickMagnitude > joystickDeadZone else {
            return .idle
        }

        if y < -diagonalDirectionThreshold {
            if driveMode == .mechanum, x < -diagonalDirectionThreshold {
                return .forwardLeft
            }

            if driveMode == .mechanum, x > diagonalDirectionThreshold {
                return .forwardRight
            }

            return .forward
        }

        if y > diagonalDirectionThreshold {
            if driveMode == .mechanum, x < -diagonalDirectionThreshold {
                return .backwardLeft
            }

            if driveMode == .mechanum, x > diagonalDirectionThreshold {
                return .backwardRight
            }

            return .backward
        }

        if x < -diagonalDirectionThreshold {
            return .left
        }

        if x > diagonalDirectionThreshold {
            return .right
        }

        if abs(y) >= abs(x) {
            return y < stoppedVelocity ? .forward : .backward
        }

        return x < stoppedVelocity ? .left : .right
    }

    private func sendRemoteControlledMode() {
        transport.call(
            service: setModeService,
            serviceType: "edu_robot/srv/SetMode",
            request: [
                "mode": .object([
                    "mode": .double(remoteControlledModeValue),
                    "drive_kinematic": .double(driveMode.driveKinematicValue),
                    "feature_mode": .double(featureModeValue)
                ]),
                "disable_feature": .double(enableFeatureValue)
            ]
        )
    }

    private func sendDisabledMode() {
        transport.call(
            service: setModeService,
            serviceType: "edu_robot/srv/SetMode",
            request: [
                "mode": .object([
                    "mode": .double(disabledModeValue),
                    "drive_kinematic": .double(driveMode.driveKinematicValue),
                    "feature_mode": .double(featureModeValue)
                ]),
                "disable_feature": .double(disableFeatureValue)
            ]
        )
    }

    private func sendJoystickDriveCommand() {
        guard joystickMagnitude > joystickDeadZone || activeRotationDirection != nil else {
            sendStopCommand()
            return
        }

        switch driveMode {
        case .mechanum:
            sendDriveCommand(
                linearX: joystickMagnitude > joystickDeadZone ? forwardVelocity : stoppedVelocity,
                linearY: joystickMagnitude > joystickDeadZone ? lateralVelocity : stoppedVelocity,
                angularZ: rotationVelocity
            )
        case .offroad:
            sendDriveCommand(linearX: forwardVelocity, angularZ: turnVelocity)
        }
    }

    private func sendDriveCommand(linearX: Double, linearY: Double = 0.0, angularZ: Double = 0.0) {
        activeCommandTransport.drive(
            x: linearX,
            y: linearY,
            rotation: angularZ
        )
    }

    private func sendStopCommand() {
        activeCommandTransport.stop()
    }

    private var forwardVelocity: Double {
        -joystickInput.y * virtualJoystickVelocityScale
    }

    private var lateralVelocity: Double {
        -joystickInput.x * virtualJoystickVelocityScale
    }

    private var turnVelocity: Double {
        -joystickInput.x * maxAngularSpeed
    }

    private var rotationVelocity: Double {
        switch activeRotationDirection {
        case .left:
            return maxAngularSpeed
        case .right:
            return -maxAngularSpeed
        case nil:
            return stoppedVelocity
        }
    }

    private var rotationStatusMessage: String {
        switch activeRotationDirection {
        case .left:
            return "\(driveMode.rawValue): rotate left."
        case .right:
            return "\(driveMode.rawValue): rotate right."
        case nil:
            return "Joystick neutral."
        }
    }

    private var joystickMagnitude: Double {
        sqrt((joystickInput.x * joystickInput.x) + (joystickInput.y * joystickInput.y))
    }

    private func normalizedJoystickInput(x: Double, y: Double) -> (x: Double, y: Double) {
        let clampedX = min(max(x, joystickMinimumInput), joystickMaximumInput)
        let clampedY = min(max(y, joystickMinimumInput), joystickMaximumInput)
        let magnitude = sqrt((clampedX * clampedX) + (clampedY * clampedY))

        guard magnitude > joystickMaximumInput else {
            return (x: clampedX, y: clampedY)
        }

        return (
            x: clampedX / magnitude,
            y: clampedY / magnitude
        )
    }
}
