//
//  RobotRemoteController.swift
//  EdukARt
//

import Combine
import Foundation

final class RobotRemoteController: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var isEnabled = false
    @Published private(set) var isDrivingForward = false
    @Published private(set) var statusMessage = "Verbinde das iPhone zuerst mit dem WLAN Eduard_Blue3."

    let transport: RobotCommandTransport

    private let setModeService = "set_mode"
    private let driveForwardTopic = "cmd_vel"
    private var commandTimer: Timer?

    init(transport: RobotCommandTransport = WiFiRobotCommandTransport()) {
        self.transport = transport
    }

    deinit {
        commandTimer?.invalidate()
    }

    func connect() {
        guard isConnected == false else {
            return
        }

        isConnected = true
        statusMessage = "Sende an \(transport.targetHost):\(transport.targetPort)."
    }

    func disconnect() {
        commandTimer?.invalidate()
        commandTimer = nil
        isDrivingForward = false
        isConnected = false
        isEnabled = false
        statusMessage = "Getrennt. Verbinde das iPhone mit Eduard_Blue3 und starte erneut."
    }

    func sendEnable() {
        guard isConnected else {
            statusMessage = "Erst WLAN-Verbindung starten, dann Enable senden."
            return
        }

        sendRemoteControlledMode()
        sendStopCommand()
        isEnabled = true
        statusMessage = "Enable aktiv."
        startCommandLoop()
    }

    func toggleDriveForward() {
        guard isConnected else {
            statusMessage = "Erst WLAN-Verbindung starten, dann Drive-Forward senden."
            return
        }

        guard isEnabled else {
            statusMessage = "Erst Enable senden, dann Drive-Forward starten."
            return
        }

        if isDrivingForward {
            stopDriveForward()
        } else {
            startDriveForward()
        }
    }

    private func startDriveForward() {
        isDrivingForward = true
        sendDriveForwardCommand()
        statusMessage = "Drive-Forward aktiv."
    }

    private func startCommandLoop() {
        commandTimer?.invalidate()
        commandTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, self.isConnected, self.isEnabled else {
                return
            }

            if self.isDrivingForward {
                self.sendDriveForwardCommand()
            } else {
                self.sendStopCommand()
            }
        }
    }

    private func stopDriveForward() {
        isDrivingForward = false
        sendStopCommand()
        statusMessage = "Drive-Forward gestoppt."
    }

    private func sendRemoteControlledMode() {
        transport.call(
            service: setModeService,
            serviceType: "edu_robot/srv/SetMode",
            request: [
                "mode": .object([
                    "mode": .double(2),
                    "drive_kinematic": .double(2),
                    "feature_mode": .double(0)
                ]),
                "disable_feature": .double(0)
            ]
        )
    }

    private func sendDriveForwardCommand() {
        transport.send(
            topic: driveForwardTopic,
            messageType: "geometry_msgs/msg/Twist",
            message: [
                "linear": .object([
                    "x": .double(1.0),
                    "y": .double(0.0),
                    "z": .double(0.0)
                ]),
                "angular": .object([
                    "x": .double(0.0),
                    "y": .double(0.0),
                    "z": .double(0.0)
                ])
            ]
        )
    }

    private func sendStopCommand() {
        transport.send(
            topic: driveForwardTopic,
            messageType: "geometry_msgs/msg/Twist",
            message: [
                "linear": .object([
                    "x": .double(0.0),
                    "y": .double(0.0),
                    "z": .double(0.0)
                ]),
                "angular": .object([
                    "x": .double(0.0),
                    "y": .double(0.0),
                    "z": .double(0.0)
                ])
            ]
        )
    }
}
