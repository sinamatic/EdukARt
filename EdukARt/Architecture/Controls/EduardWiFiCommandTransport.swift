//
//  WiFiRobotCommandTransport.swift
//  EdukARt
//

import Foundation
import Network

final class WiFiRobotCommandTransport: RobotCommandTransport {
    let targetHost: String
    let targetPort: UInt16

    private let connection: NWConnection
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

    func send(topic: String, messageType: String, message: [String: ROSValue]) {
        let command = ROSPublishCommand(
            topic: topic,
            messageType: messageType,
            message: message
        )

        send(command)
    }

    func call(service: String, serviceType: String, request: [String: ROSValue]) {
        let command = ROSServiceCommand(
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
}
