//
//  EduardWiFiCommandTransport.swift
//  EdukARt
//
//  - Oeffnet eine UDP-Verbindung zum Eduard-Roboter im WLAN.
//  - Codiert Eduard-ROS-Kommandos als JSON.
//  - Sendet jedes JSON-Paket mit abschliessendem Newline an das Python-Skript.

import Foundation
import Network

final class EduardWiFiCommandTransport: EduardROSCommandTransport {
    let targetHost: String
    let targetPort: UInt16

    private var connection: NWConnection
    private let encoder = JSONEncoder()

    init(targetHost: String = "192.168.0.100", targetPort: UInt16 = 50505) {
        self.targetHost = targetHost
        self.targetPort = targetPort

        let endpointHost = NWEndpoint.Host(targetHost)
        let endpointPort = NWEndpoint.Port(rawValue: targetPort) ?? 50505
        connection = NWConnection(host: endpointHost, port: endpointPort, using: .udp)
        connection.start(queue: .global(qos: .userInitiated))
    }

    deinit {
        connection.cancel()
    }

    func reconnect() {
        connection.cancel()
        connection = makeConnection()
        connection.start(queue: .global(qos: .userInitiated))
    }

    func send(topic: String, messageType: String, message: [String: EduardROSValue]) {
        let command = EduardROSPublishCommand(
            topic: topic,
            messageType: messageType,
            message: message
        )

        send(command)
    }

    func call(service: String, serviceType: String, request: [String: EduardROSValue]) {
        let command = EduardROSServiceCommand(
            service: service,
            serviceType: serviceType,
            request: request
        )

        send(command)
    }

    private func send<Command: Encodable>(_ command: Command) {
        guard let encodedCommand = try? encoder.encode(command) else {
            return
        }

        var packet = encodedCommand
        packet.append(0x0A)
        connection.send(content: packet, completion: .contentProcessed { _ in })
    }

    private func makeConnection() -> NWConnection {
        let endpointHost = NWEndpoint.Host(targetHost)
        let endpointPort = NWEndpoint.Port(rawValue: targetPort) ?? 50505

        return NWConnection(host: endpointHost, port: endpointPort, using: .udp)
    }
}
