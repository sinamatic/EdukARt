//
//  SimulationCommandTransport.swift
//  EdukARt
//

import Foundation

final class SimulationCommandTransport:
    RobotCommandTransport {
    
    private let simulatedRobot:
        SimulatedRobotController
    
    private let movementScale: Double = 0.7
    private let rotationScale: Double = 0.7
    
    
    init(
        simulatedRobot: SimulatedRobotController
    ) {
        self.simulatedRobot = simulatedRobot
    }
    
    
    func drive(
        x: Double,
        y: Double,
        rotation: Double
    ) {
        
        simulatedRobot.setMovement(
            x: Float(-y * movementScale),
            y: Float(-x * movementScale),
            rotation: Float(-rotation * rotationScale)
        )
    }
    
    
    func stop() {
        simulatedRobot.stop()
    }
}
