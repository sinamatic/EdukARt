//
//  RobotCommandTransport.swift
//  EdukARt
//

import Foundation

protocol RobotCommandTransport: AnyObject {
    
    func drive(
        x: Double,
        y: Double,
        rotation: Double
    )
    
    func stop()
}
