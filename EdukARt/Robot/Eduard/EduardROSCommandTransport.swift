//
//  EduardROSCommandTransport.swift
//  EdukARt
//
//  - Beschreibt die ROS-Kommandos, die das Python-Skript erwartet.
//  - Verpackt Publish- und Service-Aufrufe als JSON-codierbare Swift-Typen.
//  - Wird von konkreten Transporten wie WLAN/UDP zum Senden genutzt.

import Foundation

protocol EduardROSCommandTransport: AnyObject {
    var targetHost: String { get }
    var targetPort: UInt16 { get }

    func reconnect()
    func send(topic: String, messageType: String, message: [String: EduardROSValue])
    func call(service: String, serviceType: String, request: [String: EduardROSValue])
}

final class EduardRobotCommandTransport: RobotCommandTransport {
    private let transport: EduardROSCommandTransport
    private let driveVelocityTopic = "cmd_vel"
    private let stoppedVelocity = 0.0

    init(transport: EduardROSCommandTransport) {
        self.transport = transport
    }

    func drive(x: Double, y: Double, rotation: Double) {
        transport.send(
            topic: driveVelocityTopic,
            messageType: "geometry_msgs/msg/Twist",
            message: [
                "linear": .object([
                    "x": .double(x),
                    "y": .double(y),
                    "z": .double(stoppedVelocity)
                ]),
                "angular": .object([
                    "x": .double(stoppedVelocity),
                    "y": .double(stoppedVelocity),
                    "z": .double(rotation)
                ])
            ]
        )
    }

    func stop() {
        drive(
            x: stoppedVelocity,
            y: stoppedVelocity,
            rotation: stoppedVelocity
        )
    }
}

indirect enum EduardROSValue: Encodable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([EduardROSValue])
    case object([String: EduardROSValue])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

struct EduardROSPublishCommand: Encodable {
    let kind = "publish"
    let topic: String
    let messageType: String
    let message: [String: EduardROSValue]
}

struct EduardROSServiceCommand: Encodable {
    let kind = "service"
    let service: String
    let serviceType: String
    let request: [String: EduardROSValue]
}
