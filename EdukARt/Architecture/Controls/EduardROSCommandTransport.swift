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

    func send(topic: String, messageType: String, message: [String: EduardROSValue])
    func call(service: String, serviceType: String, request: [String: EduardROSValue])
}

indirect enum EduardROSValue: Encodable {
    case bool(Bool)
    case double(Double)
    case string(String)
    case object([String: EduardROSValue])

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
