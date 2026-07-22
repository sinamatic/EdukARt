//
//  RobotCommandTransport.swift
//  EdukARt
//

import Foundation

protocol RobotCommandTransport: AnyObject {
    var targetHost: String { get }
    var targetPort: UInt16 { get }

    func sendDrive(input: ControlInput, rotation: Float)
    func sendEnable()
    func sendStop()
}

struct RobotRemoteCommand: Codable {
    let type: String
    let x: Float
    let y: Float
    let rotation: Float
    let timestamp: TimeInterval

    static func drive(input: ControlInput, rotation: Float) -> RobotRemoteCommand {
        RobotRemoteCommand(
            type: "drive",
            x: input.direction.x,
            y: input.direction.y,
            rotation: rotation,
            timestamp: Date().timeIntervalSince1970
        )
    }

    static func action(_ type: String) -> RobotRemoteCommand {
        RobotRemoteCommand(
            type: type,
            x: 0,
            y: 0,
            rotation: 0,
            timestamp: Date().timeIntervalSince1970
        )
    }
}
