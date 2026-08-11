//
//  RobotCommandTransport.swift
//  EdukARt
//

import Foundation

protocol RobotCommandTransport: AnyObject {
    var targetHost: String { get }
    var targetPort: UInt16 { get }

    func send(topic: String, messageType: String, message: [String: ROSValue])
    func call(service: String, serviceType: String, request: [String: ROSValue])
}

indirect enum ROSValue: Encodable {
    case bool(Bool)
    case double(Double)
    case string(String)
    case object([String: ROSValue])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

struct ROSPublishCommand: Encodable {
    let kind = "publish"
    let topic: String
    let messageType: String
    let message: [String: ROSValue]
}

struct ROSServiceCommand: Encodable {
    let kind = "service"
    let service: String
    let serviceType: String
    let request: [String: ROSValue]
}
