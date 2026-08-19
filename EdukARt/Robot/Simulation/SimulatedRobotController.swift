//
//  SimulatedRobotController.swift
//  EdukARt
//

import Combine
import Foundation
import simd

final class SimulatedRobotController:
    ObservableObject {
    
    @Published private(set)
    var position =
        SIMD3<Float>.zero
    
    @Published private(set)
    var rotation: Float = 0
    
    
    private var movementX: Float = 0
    private var movementY: Float = 0
    private var rotationInput: Float = 0
    
    private var targetMovementX: Float = 0
    private var targetMovementY: Float = 0
    private var targetRotationInput: Float = 0
    
    
    private var timer: Timer?
    
    
    private let updateInterval: TimeInterval = 1.0 / 30.0
    private let moveSpeed: Float = 0.38
    private let rotationSpeed: Float = .pi / 2.4
    private let inputSmoothing: Float = 0.22
    
    
    init() {
        startTimer()
    }
    
    
    func setMovement(
        x: Float,
        y: Float,
        rotation: Float
    ) {
        targetMovementX = x
        targetMovementY = y
        targetRotationInput = rotation
    }
    
    
    func stop() {
        targetMovementX = 0
        targetMovementY = 0
        targetRotationInput = 0
    }
    
    
    func reset() {
        position = .zero
        rotation = 0
        
        movementX = 0
        movementY = 0
        rotationInput = 0
        
        targetMovementX = 0
        targetMovementY = 0
        targetRotationInput = 0
    }
    
    
    private func startTimer() {
        
        timer = Timer.scheduledTimer(
            withTimeInterval: updateInterval,
            repeats: true
        ) { [weak self] _ in
            
            self?.updateMovement()
        }
    }
    
    
    private func updateMovement() {
        
        let deltaTime = Float(updateInterval)
        
        movementX +=
            (targetMovementX - movementX) *
            inputSmoothing
        
        movementY +=
            (targetMovementY - movementY) *
            inputSmoothing
        
        rotationInput +=
            (targetRotationInput - rotationInput) *
            inputSmoothing
        
        
        // Rotation
        
        rotation +=
            rotationInput *
            rotationSpeed *
            deltaTime
        
        
        // Joystickbewegung relativ zur Roboterorientierung
        
        let cosRotation = cos(rotation)
        let sinRotation = sin(rotation)
        
        
        let localX =
            movementX * moveSpeed * deltaTime
        
        let localY =
            movementY * moveSpeed * deltaTime
        
        
        let worldX =
            localX * cosRotation -
            localY * sinRotation
        
        let worldY =
            localX * sinRotation +
            localY * cosRotation
        
        
        position.x += worldX
        position.y += worldY
    }
    
    
    deinit {
        timer?.invalidate()
    }
}
